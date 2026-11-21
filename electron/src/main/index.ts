import { app, BrowserWindow, dialog, ipcMain, Menu, Tray, nativeImage, screen } from 'electron'
import { join } from 'path'
import { mkdirSync, writeFileSync } from 'fs'
import { trayIconDataUrl } from './icon'

// The Go service passes the same runtime arguments it gives the Flutter shell:
//   --api-port=<port> --auth-token=<token>
// Extra flags exist for headless verification of the visual pass:
//   --screenshot=<png> --screen=home|library|quiz|stats --theme=light|dark --lang=zh|en|ja
//   --nowindow --lock-demo
// Accepts both --name=value (our dev scripts) and --name value (the Go service
// passes the port as a separate argv entry, which silently produced a null port
// and a shell stuck on demo data).
function readArg(name: string): string | undefined {
  const prefix = '--' + name + '='
  const hit = process.argv.find((a) => a.startsWith(prefix))
  if (hit) return hit.slice(prefix.length)
  const idx = process.argv.indexOf('--' + name)
  if (idx >= 0 && idx + 1 < process.argv.length && !process.argv[idx + 1].startsWith('--')) {
    return process.argv[idx + 1]
  }
  return undefined
}

const apiPort = readArg('api-port')
const authTokenArg = readArg('auth-token')

// In dev mode the Go service spawns "electron.exe <app-dir> --api-port=…
// --remote-debugging-port=…"; Chromium switches placed after the app path are
// treated as app arguments, so re-register the DevTools port before ready.
const remoteDebugPort = readArg('remote-debugging-port')
if (remoteDebugPort) {
  app.commandLine.appendSwitch('remote-debugging-port', remoteDebugPort)
}

// The Go service hands the token over stdin so it never appears in a process
// listing (same rule the Flutter shell followed).
const stdinToken = new Promise<string | null>((resolve) => {
  const fromEnv = process.env['VOCABLOCK_AUTH_TOKEN']
  if (fromEnv) {
    resolve(fromEnv)
    return
  }
  if (!process.argv.includes('--auth-token-stdin')) {
    resolve(authTokenArg ?? null)
    return
  }
  let buf = ''
  process.stdin.setEncoding('utf8')
  process.stdin.on('data', (chunk) => {
    buf += chunk
  })
  process.stdin.on('end', () => resolve(buf.trim() || null))
  // If nothing arrives, fail open to "no token" rather than hanging the shell.
  setTimeout(() => resolve(buf.trim() || null), 5000)
})
const screenshotPath = readArg('screenshot')
const initialScreen = readArg('screen') ?? 'home'
const initialTheme = readArg('theme')
const initialLang = readArg('lang')
const hidden = process.argv.includes('--nowindow')
const lockDemo = process.argv.includes('--lock-demo')
const captureMode = Boolean(screenshotPath)

let win: BrowserWindow | null = null
let lockWin: BrowserWindow | null = null
let tray: Tray | null = null
let quitting = false
let locked = false

// One VocabLock per machine: a second launch focuses the running window instead
// of starting a second service/UI pair.
const singleInstance = app.requestSingleInstanceLock()
if (!singleInstance) {
  console.log('single-instance: another VocabLock is already running')
  app.quit()
}

function rendererUrl(): { url?: string; file?: string } {
  const devUrl = process.env['ELECTRON_RENDERER_URL']
  return devUrl ? { url: devUrl } : { file: join(__dirname, '../renderer/index.html') }
}

function baseWindowOptions(): Electron.BrowserWindowConstructorOptions {
  return {
    width: 1280,
    height: 800,
    minWidth: 1040,
    minHeight: 680,
    frame: false,
    backgroundColor: initialTheme === 'light' ? '#F4F4F1' : '#0B0D10',
    title: 'VocabLock',
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      sandbox: false,
      contextIsolation: true,
      // Scripted captures run against a hidden window: without this Electron
      // throttles rAF/timers and React can stay on its "Loading…" frame.
      backgroundThrottling: false
    }
  }
}

function loadInto(target: BrowserWindow): void {
  const target_ = rendererUrl()
  if (target_.url) void target.loadURL(target_.url)
  else if (target_.file) void target.loadFile(target_.file)
}

// Testing and focus sessions can be pinned to a secondary display with
// VOCABLOCK_WINDOW_DISPLAY=2 (1-based); the default remains the primary screen.
function targetDisplay(): ReturnType<typeof screen.getPrimaryDisplay> {
  const raw = process.env.VOCABLOCK_WINDOW_DISPLAY
  const all = screen.getAllDisplays()
  const primary = screen.getPrimaryDisplay()
  if (raw) {
    const idx = Number(raw) - 1
    if (Number.isFinite(idx) && all[idx]) return all[idx]
    return primary
  }
  // Default to the secondary display when one exists, so launches (including
  // the autostart entry) never cover the user's primary workspace.
  return all.find((d) => d.id !== primary.id) ?? primary
}

function createWindow(): void {
  // A fixed 1280x800 looked tiny on a 1440p/1080p desktop; size the window to
  // most of the work area while staying above the layout's minimum.
  const display = targetDisplay()
  const { width: areaW, height: areaH } = display.workAreaSize
  const width = Math.min(1440, Math.max(1040, Math.round(areaW * 0.9)))
  const height = Math.min(920, Math.max(680, Math.round(areaH * 0.9)))
  // Scripted captures need a painting window; park it far off-screen and show
  // it without activation so the user keeps focus on whatever they are doing.
  win = new BrowserWindow({
    ...baseWindowOptions(),
    ...(captureMode
      ? { width, height, x: -32000, y: -32000 }
      : {
          x: display.bounds.x,
          y: display.bounds.y,
          width: display.bounds.width,
          height: display.bounds.height,
          fullscreen: true,
          fullscreenable: true
        }),
    show: false
  })
  win.once('ready-to-show', async () => {
    if (!win) return
    if (captureMode) {
      win.showInactive()
      return
    }
    if (hidden) return
    // Constructed fullscreen on the target display; show it that way rather
    // than showing a window and waiting for a later maximize click.
    await pollLockState()
    win.show()
    if (locked) applyFocusWindow(true)
  })
  loadInto(win)

  // Renderer errors otherwise vanish in a packaged build (no devtools). Forward
  // them to the service log so a blank screen can be diagnosed from stderr.
  win.webContents.on('console-message', (_event, level, message, line, sourceId) => {
    if (level >= 2) console.error('[renderer]', message, sourceId ? '(' + sourceId + ':' + line + ')' : '')
  })
  win.webContents.on('render-process-gone', (_event, details) => {
    console.error('[renderer] process gone:', details.reason, details.exitCode)
  })

  // Closing the window parks the app in the tray; quitting goes through the menu
  // (or app.quit), so the service keeps running and the lock stays armed.
  win.on('resize', () => {
    if (locked && !quitting && win && !win.isFullScreen()) win.setFullScreen(true)
  })
  win.on('close', (event) => {
    // Focus mode: the window is not closable until today's quota is done.
    if (locked && !quitting) {
      event.preventDefault()
      win?.show()
      win?.focus()
      void dialog.showMessageBox(win!, {
        type: 'info',
        title: '专注模式',
        message: '完成今日学习目标后才能关闭窗口。',
        detail: '达标后会自动解锁，届时可以直接关闭。',
        buttons: ['继续学习']
      })
      return
    }
    // After the quota is met the user is released: closing the window quits.
    if (!quitting) {
      quitting = true
      app.quit()
    }
  })
  win.on('closed', () => {
    win = null
  })

  if (screenshotPath) captureScreenshot(screenshotPath)
}

function captureScreenshot(path: string): void {
  if (!win) return
  win.webContents.once('did-finish-load', () => {
    void (async () => {
      const deadline = Date.now() + 15000
      while (Date.now() < deadline) {
        if (!win) return
        const ready = await win.webContents.executeJavaScript("!!document.querySelector('.app')").catch(() => false)
        if (ready) break
        await new Promise((r) => setTimeout(r, 200))
      }
      await new Promise((r) => setTimeout(r, 600))
      if (!win) return
      const image = await win.webContents.capturePage()
      mkdirSync(join(path, '..'), { recursive: true })
      writeFileSync(path, image.toPNG())
      console.log('screenshot:', path)
      app.quit()
    })()
  })
}

/**
 * The system-level lock: a frameless, kiosk, always-on-top window covering the
 * primary display. The Go service decides *when* (daily target, escape), the
 * shell decides *how* — the old Win32 lock window only knew about Flutter.
 */
function createLockWindow(): void {
  // Focus mode is enforced by blocking close/quit until the quota is met.
  // There is deliberately no separate lock screen or kiosk window.
}
function destroyLockWindow(): void {
  if (!lockWin) return
  const target = lockWin
  lockWin = null
  target.destroy()
}

function applyFocusWindow(lock: boolean): void {
  if (!win || captureMode || hidden) return
  win.setResizable(!lock)
  win.setMinimizable(!lock)
  win.setMaximizable(!lock)
  win.setClosable(!lock)
  if (lock) {
    const display = targetDisplay()
    const bounds = { x: display.bounds.x, y: display.bounds.y, width: display.bounds.width, height: display.bounds.height }
    try {
      win.setKiosk(false)
    } catch {
      /* not in kiosk */
    }
    win.setBounds(bounds)
    // Do not setBounds again after entering fullscreen: on Windows the second
    // bounds write can cancel the fullscreen transition.
    win.setFullScreen(true)
    win.show()
    win.focus()
  } else {
    win.setKiosk(false)
    win.setFullScreen(false)
  }
}

function setLocked(next: boolean): void {
  const changed = locked !== next
  locked = next
  if (next) createLockWindow()
  else destroyLockWindow()
  applyFocusWindow(next)
  if (changed && win) {
    win.webContents.send('lock-state', next)
  }
}

function createTray(): void {
  const image = nativeImage.createFromDataURL(trayIconDataUrl).resize({ width: 16, height: 16 })
  tray = new Tray(image)
  tray.setToolTip('VocabLock')
  tray.setContextMenu(
    Menu.buildFromTemplate([
      {
        label: '显示 VocabLock',
        click: () => {
          win?.show()
          win?.focus()
        }
      },
      {
        label: '锁屏专注',
        click: () => void requestLock()
      },
      { type: 'separator' },
      {
        label: '退出',
        click: () => {
          quitting = true
          app.quit()
        }
      }
    ])
  )
  tray.on('click', () => {
    if (win?.isVisible()) win.hide()
    else {
      win?.show()
      win?.focus()
    }
  })
}

async function api(path: string, init?: RequestInit): Promise<Response | null> {
  const token = await stdinToken
  if (!apiPort || !token) return null
  return fetch('http://127.0.0.1:' + apiPort + path, {
    ...init,
    headers: { Authorization: 'Bearer ' + token, ...(init?.body ? { 'Content-Type': 'application/json' } : {}) }
  })
}

async function requestLock(): Promise<void> {
  const res = await api('/api/v1/system/lock', { method: 'POST' })
  if (res && res.ok) setLocked(true)
}

/** Follow the service's lock state so auto-lock and emergency escape still work. */
async function pollLockState(): Promise<void> {
  const res = await api('/api/v1/system/status')
  if (!res || !res.ok) return
  const body = (await res.json()) as { locked?: boolean }
  if (typeof body.locked === 'boolean' && body.locked !== locked) setLocked(body.locked)
}

ipcMain.handle('runtime:config', async (event) => {
  const sender = BrowserWindow.fromWebContents(event.sender)
  return {
    apiPort: apiPort ?? null,
    authToken: await stdinToken,
    screen: sender && lockWin && sender.id === lockWin.id ? 'lock' : initialScreen,
    theme: initialTheme ?? null,
    lang: initialLang ?? null,
    locked
  }
})

ipcMain.handle('app:info', () => ({
  singleInstance,
  windows: BrowserWindow.getAllWindows().length,
  tray: Boolean(tray),
  locked,
  lockWindow: Boolean(lockWin),
  kiosk: lockWin ? lockWin.isKiosk() : false,
  alwaysOnTop: lockWin ? lockWin.isAlwaysOnTop() : false
}))

ipcMain.on('window:minimize', () => {
  if (locked) return
  win?.minimize()
})
ipcMain.on('window:maximize', () => {
  if (!win || locked) return
  if (win.isMaximized()) win.unmaximize()
  else win.maximize()
})
ipcMain.on('window:close', () => win?.close())
ipcMain.on('lock:request', () => void requestLock())
ipcMain.on('lock:dismiss', () => {
  // Only the service may release a focus lock (daily quota met). Renderer
  // shortcuts must not be able to dismiss it.
  if (locked) return
  setLocked(false)
})
// "Start studying" on the lock screen: the lock is a focus screen, not a
// quiz, so give it an explicit way into the real session instead of leaving
// the user to guess that Esc is the only exit.
ipcMain.on('lock:study', () => {
  // Enter the real session while keeping the focus lock armed. The lock is
  // released by the service only when the daily quota is complete.
  if (!locked) return
  lockWin?.hide()
  if (win) {
    if (win.isMinimized()) win.restore()
    win.show()
    win.moveTop()
    win.focus()
    win.webContents.send('navigate', 'quiz')
  }
})

app.on('second-instance', () => {
  if (win) {
    if (win.isMinimized()) win.restore()
    win.show()
    win.focus()
    win.webContents.send('navigate', 'home')
  }
})

if (singleInstance) {
  app.whenReady().then(() => {
    // The packaged shell is useless on its own: without the Go service it
    // falls back to demo data. Point the user at the real entry point instead
    // of silently showing an English demo vault.
    if (app.isPackaged && !process.argv.some((a) => a.startsWith('--api-port'))) {
      dialog.showErrorBox(
        'VocabLock',
        '请通过 VocabLock.exe 启动。\n\n直接运行界面外壳（vocablock-desktop.exe）只会显示演示数据。'
      )
      app.quit()
      return
    }
    createWindow()
    createTray()
    if (lockDemo) {
      // Debug hook: hold the lock window open for inspection instead of
      // letting the service state (which does not know about the demo) close it.
      setLocked(true)
    } else {
      setInterval(() => void pollLockState(), 2000)
    // Windows can ignore setFullScreen while the window is still being shown.
    // Re-assert it once the window is visible so a locked launch needs no click.
    setInterval(() => {
      if (locked && win && !win.isDestroyed() && !win.isFullScreen()) applyFocusWindow(true)
    }, 2500)
    }
    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) createWindow()
    })
  })
}

app.on('before-quit', (event) => {
  // Quit is also blocked while the daily quota is unfinished.
  if (locked && !quitting) {
    event.preventDefault()
    if (win) {
      win.show()
      win.focus()
    }
    return
  }
  quitting = true
})

app.on('window-all-closed', () => {
  // With a tray the app keeps running; without one, quit like a normal app.
  if (!quitting) {
    quitting = true
    app.quit()
  }
})