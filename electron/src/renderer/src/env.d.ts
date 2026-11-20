/// <reference types="vite/client" />

declare global {
  interface Window {
    vocablock: {
      requestLock: () => void
      dismissLock: () => void
      startStudy: () => void
      onNavigate: (cb: (screen: string) => void) => void
      onLockState: (cb: (locked: boolean) => void) => void
      appInfo: () => Promise<Record<string, unknown>>
      runtime: () => Promise<{
        apiPort: string | null
        authToken: string | null
        screen: string
        theme: string | null
        lang: string | null
        locked: boolean
      }>
      minimize: () => void
      maximize: () => void
      close: () => void
    }
  }
}

export {}
