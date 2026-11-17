/// <reference types="vite/client" />

declare global {
  interface Window {
    vocablock: {
      requestLock: () => void
      dismissLock: () => void
      appInfo: () => Promise<Record<string, unknown>>
      runtime: () => Promise<{
        apiPort: string | null
        authToken: string | null
        screen: string
        theme: string | null
        lang: string | null
      }>
      minimize: () => void
      maximize: () => void
      close: () => void
    }
  }
}

export {}
