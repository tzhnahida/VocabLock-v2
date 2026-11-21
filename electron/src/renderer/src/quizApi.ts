import { apiContext } from './api'

export type Question = {
  id: string
  type: string
  subject_type: string
  subject_id: number
  prompt: string
  options?: string[]
  subject_word?: string
  subject_reading?: string
  subject_meaning?: string
}

export type SubmitResult = {
  correct: boolean
  score: number
  feedback: string
  source: string
  next_review_at?: string | null
  transcript?: string
  expected_answer?: string
  log_id?: number
}

export type SessionStart = {
  preparing?: boolean
  daily_completed?: boolean
  empty?: boolean
  new_words?: number
  new_grammar?: number
  review_words?: number
  review_grammar?: number
}

async function call<T>(path: string, init?: RequestInit): Promise<T> {
  const ctx = apiContext()
  if (!ctx) throw new Error('no backend')
  const res = await fetch(`http://127.0.0.1:${ctx.port}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${ctx.token}`,
      ...(init?.body ? { 'Content-Type': 'application/json' } : {}),
      ...(init?.headers ?? {})
    }
  })
  if (!res.ok) {
    let detail = ''
    try {
      const body = (await res.json()) as { error?: string }
      detail = body.error ?? ''
    } catch {
      /* keep the status only */
    }
    throw new Error(detail || `${path} -> ${res.status}`)
  }
  return (await res.json()) as T
}

export type StudyCard = {
  id: number
  word: string
  reading: string
  meaning: string
  pos: string
  level?: string
  example?: string
  forms?: string
  pitch?: string
  syllables?: string
  register?: string
  morphology?: string
  collocation?: string
  syntax?: string
}

export type GrammarCard = { id: number; title: string; explanation: string; example: string; detail: string }

export function evictTTS(text: string): Promise<{ evicted: boolean }> {
  return call<{ evicted: boolean }>('/api/v1/tts/evict', {
    method: 'POST',
    body: JSON.stringify({ text })
  })
}

export type SessionProgress = { study_index: number; study_done: boolean }

export function loadSessionProgress(): Promise<SessionProgress> {
  return call<SessionProgress>('/api/v1/quiz/session/progress')
}

export function saveSessionProgress(studyIndex: number, studyDone: boolean): Promise<{ ok: boolean }> {
  return call<{ ok: boolean }>('/api/v1/quiz/session/progress', {
    method: 'POST',
    body: JSON.stringify({ study_index: studyIndex, study_done: studyDone })
  })
}

export function loadStudyCards(language: string, count = 8): Promise<{ cards: StudyCard[]; grammar: GrammarCard[] }> {
  return call<{ cards: StudyCard[]; grammar?: GrammarCard[] }>(
    '/api/v1/quiz/study-cards?count=' + count + '&language=' + encodeURIComponent(language)
  ).then((r) => ({ cards: r.cards ?? [], grammar: r.grammar ?? [] }))
}

export type PlanSummary = {
  message?: string
  warning?: string
  summary?: Record<string, unknown>
  plan?: {
    direction?: string
    direction_confidence?: number
    tomorrow?: { word_count?: number; difficulty?: string; question_type_ratio?: Record<string, number> }
  }
}

export function summarizeSession(): Promise<PlanSummary> {
  return call<PlanSummary>('/api/v1/quiz/summarize', { method: 'POST', body: JSON.stringify({}) })
}

export type PronounceResult = {
  status: 'ok' | 'not_configured' | 'error'
  score: number
  phonemes?: Array<{ phoneme: string; score: number }>
  detail?: string
  error?: string
}

export function assessPronounce(audio: string, wordId: number): Promise<PronounceResult> {
  return call<PronounceResult>('/api/v1/pronounce/assess', {
    method: 'POST',
    body: JSON.stringify({ audio, word_id: wordId })
  })
}

export function recordStudyTime(seconds: number, wordId: number): Promise<{ ok: boolean; time_used: number }> {
  return call<{ ok: boolean; time_used: number }>('/api/v1/quiz/study-time', {
    method: 'POST',
    body: JSON.stringify({ seconds, word_id: wordId })
  })
}

export function continueSession(): Promise<{ ok: boolean; continue: boolean }> {
  return call<{ ok: boolean; continue: boolean }>('/api/v1/quiz/session/continue', {
    method: 'POST',
    body: JSON.stringify({})
  })
}

export function startSession(language: string): Promise<SessionStart> {
  return call<SessionStart>('/api/v1/quiz/session/start', {
    method: 'POST',
    body: JSON.stringify({ language })
  })
}

export async function nextQuestion(language: string): Promise<Question | null> {
  const data = await call<Question & { completed?: boolean }>(
    `/api/v1/quiz/next?language=${encodeURIComponent(language)}`
  )
  return data.completed ? null : data
}

export function submitAnswer(input: {
  questionId: string
  subjectType: string
  subjectId: number
  questionType: string
  answer: string
  language: string
  audio?: string
}): Promise<SubmitResult> {
  return call<SubmitResult>('/api/v1/quiz/submit', {
    method: 'POST',
    body: JSON.stringify({
      question_id: input.questionId,
      subject_type: input.subjectType,
      subject_id: input.subjectId,
      question_type: input.questionType,
      answer: input.answer,
      language: input.language,
      ...(input.audio ? { audio: input.audio } : {})
    })
  })
}

export function completeSession(): Promise<unknown> {
  return call('/api/v1/quiz/complete', { method: 'POST' })
}

/** Marks a verdict the student disagrees with; diagnostics only, no SM-2 effect. */
export function disputeAnswer(logId: number): Promise<unknown> {
  return call('/api/v1/quiz/dispute', {
    method: 'POST',
    body: JSON.stringify({ log_id: logId })
  })
}
