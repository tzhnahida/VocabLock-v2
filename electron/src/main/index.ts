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
const authToken = readArg('auth-token')
const screenshotPath = readArg('screenshot')
const initialScreen = readArg('screen') ?? 'home'
const initialTheme = readArg('theme')
const initialLang = readArg('lang')
const hidden = process.argv.includes('--nowindow')

let win: BrowserWindow | null = null

function createWindow(): void {
  win = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 1040,
    minHeight: 680,
    show: !screenshotPath && !hidden,
    frame: false,
    backgroundColor: initialTheme === 'light' ? '#F4F4F1' : '#0B0D10',
    title: 'VocabLock',
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      sandbox: false,
      contextIsolation: true
    }
  })

  const devUrl = process.env['ELECTRON_RENDERER_URL']
  if (devUrl) {
    void win.loadURL(devUrl)
  } else {
    void win.loadFile(join(__dirname, '../renderer/index.html'))
  }

  win.on('closed', () => {
    win = null
  })

  if (screenshotPath) {
    win.webContents.once('did-finish-load', () => {
      // Give React one animation frame plus the data fetch a moment to settle.
      setTimeout(async () => {
        if (!win) return
        const image = await win.webContents.capturePage()
        const dir = join(screenshotPath, '..')
        mkdirSync(dir, { recursive: true })
        writeFileSync(screenshotPath, image.toPNG())
        console.log('screenshot:', screenshotPath)
        app.quit()
      }, 2500)
    })
  }
}

ipcMain.handle('runtime:config', () => ({
  apiPort: apiPort ?? null,
  authToken: authToken ?? null,
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
