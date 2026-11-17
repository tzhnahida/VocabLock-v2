import { apiContext } from './api'

export type ChatMessage = { role: 'user' | 'assistant'; content: string }

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
  if (!res.ok) {
    let detail = ''
    try {
      detail = ((await res.json()) as { error?: string }).error ?? ''
    } catch {
      /* status only */
    }
    throw new Error(detail || `${path} -> ${res.status}`)
  }
  return (await res.json()) as T
}

export type ChatReply = { reply: string; model: string }

export function sendChat(message: string, history: ChatMessage[]): Promise<ChatReply> {
  return call<ChatReply>('/api/v1/ai/chat', {
    method: 'POST',
    body: JSON.stringify({ message, history: history.slice(-10) })
  })
}
