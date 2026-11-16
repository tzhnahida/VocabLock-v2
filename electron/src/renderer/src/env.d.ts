/// <reference types="vite/client" />

declare global {
  interface Window {
    vocablock: {
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
