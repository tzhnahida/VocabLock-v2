import { contextBridge, ipcRenderer } from 'electron'

export type RuntimeConfig = {
  apiPort: string | null
  authToken: string | null
  screen: string
  theme: string | null
  lang: string | null
}

contextBridge.exposeInMainWorld('vocablock', {
  runtime: (): Promise<RuntimeConfig> => ipcRenderer.invoke('runtime:config'),
  minimize: (): void => ipcRenderer.send('window:minimize'),
  maximize: (): void => ipcRenderer.send('window:maximize'),
  close: (): void => ipcRenderer.send('window:close'),
  requestLock: (): void => ipcRenderer.send('lock:request'),
  dismissLock: (): void => ipcRenderer.send('lock:dismiss'),
  startStudy: (): void => ipcRenderer.send('lock:study'),
  onNavigate: (cb: (screen: string) => void): void => {
    ipcRenderer.on('navigate', (_event, screen: string) => cb(screen))
  },
  appInfo: (): Promise<Record<string, unknown>> => ipcRenderer.invoke('app:info')
})
