import { apiContext } from './api'

export type TTSResult = { status: string; url: string; format?: string; cached?: boolean; error?: string }

async function call<T>(path: string, init?: RequestInit): Promise<T> {
  const ctx = apiContext()
  if (!ctx) throw new Error('no backend')
  const res = await fetch(`http://127.0.0.1:${ctx.port}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${ctx.token}`,
      ...(init?.body ? { 'Content-Type': 'application/json' } : {})
    }
  })
  if (!res.ok) throw new Error(`${path} -> ${res.status}`)
  return (await res.json()) as T
}

export async function audioObjectUrl(path: string): Promise<string> {
  const ctx = apiContext()
  if (!ctx) throw new Error('no backend')
  const res = await fetch(`http://127.0.0.1:${ctx.port}${path}`, {
    headers: { Authorization: `Bearer ${ctx.token}` }
  })
  if (!res.ok) throw new Error(`audio ${res.status}`)
  return URL.createObjectURL(await res.blob())
}

export function wordAudio(wordId: number): Promise<TTSResult> {
  return call<TTSResult>(`/api/v1/tts/word/${wordId}`)
}

export function evictTTS(text: string): Promise<{ evicted: boolean }> {
  return call<{ evicted: boolean }>('/api/v1/tts/evict', {
    method: 'POST',
    body: JSON.stringify({ text })
  })
}

export function textAudio(text: string): Promise<TTSResult> {
  return call<TTSResult>('/api/v1/tts/text', { method: 'POST', body: JSON.stringify({ text }) })
}