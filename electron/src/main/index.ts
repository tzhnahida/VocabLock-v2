import { app, BrowserWindow, ipcMain } from 'electron'
import { join } from 'path'
import { mkdirSync, writeFileSync } from 'fs'

// The Go service passes the same runtime arguments it gives the Flutter shell:
//   --api-port=<port> --auth-token=<token>
// Extra flags exist for headless verification of the visual pass:
//   --screenshot=<png> --screen=home|library|quiz|stats --theme=light|dark --lang=zh|en|ja
function readArg(name: string): string | undefined {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`))
  return hit ? hit.slice(name.length + 3) : undefined
}

const apiPort = readArg('api-port')
const authTokenArg = readArg('auth-token')

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

let win: BrowserWindow | null = null

function createWindow(): void {
  // Scripted captures need a painting window; park it far off-screen and show
  // it without activation so the user keeps focus on whatever they are doing.
  const captureMode = Boolean(screenshotPath)
  win = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 1040,
    minHeight: 680,
    x: captureMode ? -32000 : undefined,
    y: captureMode ? -32000 : undefined,
    show: !screenshotPath && !hidden,
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
  })

  const devUrl = process.env['ELECTRON_RENDERER_URL']
  if (devUrl) {
    void win.loadURL(devUrl)
  } else {
    void win.loadFile(join(__dirname, '../renderer/index.html'))
  }

  if (captureMode) win.showInactive()

  win.on('closed', () => {
    win = null
  })

  if (screenshotPath) {
    win.webContents.once('did-finish-load', () => {
      void (async () => {
        // Wait for the shell to mount and the first data load to settle rather
        // than guessing a delay — a slow disk or a cold fetch used to produce a
        // screenshot of the "Loading…" boot state.
        const deadline = Date.now() + 15000
        while (Date.now() < deadline) {
          if (!win) return
          const ready = await win.webContents
            .executeJavaScript("!!document.querySelector('.app')")
            .catch(() => false)
          if (ready) break
          await new Promise((r) => setTimeout(r, 200))
        }
        await new Promise((r) => setTimeout(r, 600))
        if (!win) return
        const image = await win.webContents.capturePage()
        mkdirSync(join(screenshotPath, '..'), { recursive: true })
        writeFileSync(screenshotPath, image.toPNG())
        console.log('screenshot:', screenshotPath)
        app.quit()
      })()
    })
  }
}

ipcMain.handle('runtime:config', async () => ({
  apiPort: apiPort ?? null,
  authToken: await stdinToken,
  screen: initialScreen,
  theme: initialTheme ?? null,
  lang: initialLang ?? null
}))

ipcMain.on('window:minimize', () => win?.minimize())
ipcMain.on('window:maximize', () => {
  if (!win) return
  if (win.isMaximized()) win.unmaximize()
  else win.maximize()
})
ipcMain.on('window:close', () => win?.close())

app.whenReady().then(() => {
  createWindow()
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})
