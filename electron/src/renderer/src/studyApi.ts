import { apiContext } from './api'

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

// ---- assignments ----------------------------------------------------------
export type Assignment = {
  id: number
  language: string
  type: string
  prompt: string
  context: string
  status: string
  created_at: string
}

export type AssignmentList = {
  assignments: Assignment[]
  pending?: boolean
  message?: string
  reason?: 'ai_required' | 'no_due' | 'generation_failed' | string
  next_due_at?: string
}

export type AssignmentResult = {
  original: string
  corrected: string
  score: number
  feedback: string
  errors?: unknown[]
}

export function listAssignments(language: string): Promise<AssignmentList> {
  return call<AssignmentList>(`/api/v1/quiz/assignment?language=${encodeURIComponent(language)}`)
}

export function submitAssignment(assignmentId: number, answer: string): Promise<AssignmentResult> {
  return call<AssignmentResult>('/api/v1/quiz/assignment/submit', {
    method: 'POST',
    body: JSON.stringify({ assignment_id: String(assignmentId), answer })
  })
}

// ---- passive recall -------------------------------------------------------
export type PassiveCard = { word_id: number; word: string; reading: string; meaning: string }

export function passiveCard(): Promise<PassiveCard> {
  return call<PassiveCard>('/api/v1/system/passive-q')
}

export function passiveSubmit(wordId: number, recall: 'easy' | 'hard' | 'forgot'): Promise<unknown> {
  return call('/api/v1/system/passive-submit', {
    method: 'POST',
    body: JSON.stringify({ word_id: wordId, recall })
  })
}

// ---- pending review -------------------------------------------------------
export type PendingWord = {
  id: number
  word: string
  reading?: string
  meaning?: string
  pos?: string
  language?: string
}

export function listPendingWords(language: string): Promise<{ words: PendingWord[] }> {
  return call<{ words: PendingWord[] }>(`/api/v1/words/pending-review?language=${encodeURIComponent(language)}`)
}

export function acceptPendingWord(
  id: number,
  fields: { reading: string; meaning: string; pos: string }
): Promise<unknown> {
  return call(`/api/v1/words/pending-review/${id}/accept`, {
    method: 'POST',
    body: JSON.stringify(fields)
  })
}

export function rejectPendingWord(id: number): Promise<unknown> {
  return call(`/api/v1/words/pending-review/${id}/reject`, { method: 'POST' })
}
