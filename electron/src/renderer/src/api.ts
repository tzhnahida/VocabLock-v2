import { normaliseLang } from './i18n'

export type Word = {
  id: number
  word: string
  reading?: string | null
  meaning?: string | null
  pos?: string | null
  status?: string | null
  repetitions?: number | null
  interval?: number | null
  easiness_factor?: number | null
  next_review_at?: string | null
  last_review_at?: string | null
}

export type TypeRate = { total: number; correct: number }

export type Dashboard = {
  online: boolean
  languages: string[]
  activeLang: string
  interfaceLang: string
  theme: 'light' | 'dark'
  reviewedToday: number
  dailyTarget: number
  remaining: number
  accuracy: number
  streak: number
  heatmap: Record<string, number>
  words: Word[]
  totalWords: number
  typeRates: Record<string, TypeRate>
  pendingReview: number
}

function iso(offsetDays: number): string {
  const d = new Date()
  d.setDate(d.getDate() + offsetDays)
  return d.toISOString()
}

// Demo content mirrors the approved prototype so running without a Go service
// still shows the design as signed off (docs/design/app.html).
export type ApiContext = { port: string; token: string }

let context: ApiContext | null = null

/** Called once the main process hands over the Go service coordinates. */
export function configureApi(next: ApiContext | null): void {
  context = next
}

export function apiContext(): ApiContext | null {
  return context
}

const DEMO_WORDS: Word[] = [
  { id: 1, word: 'ubiquitous', reading: '/juːˈbɪk.wɪ.təs/', meaning: '无处不在的', pos: 'adj.', status: 'active', repetitions: 3, interval: 4, easiness_factor: 2.5, next_review_at: iso(4), last_review_at: iso(0) },
  { id: 2, word: 'ephemeral', reading: '/ɪˈfem.ər.əl/', meaning: '转瞬即逝的', pos: 'adj.', status: 'active', repetitions: 1, interval: 1, easiness_factor: 2.3, next_review_at: iso(0), last_review_at: iso(-1) },
  { id: 3, word: 'meticulous', reading: '/məˈtɪk.jə.ləs/', meaning: '一丝不苟的', pos: 'adj.', status: 'active', repetitions: 5, interval: 21, easiness_factor: 2.7, next_review_at: iso(21), last_review_at: iso(-2) },
  { id: 4, word: 'alleviate', reading: '/əˈliː.vi.eɪt/', meaning: '缓解', pos: 'v.', status: 'active', repetitions: 2, interval: 2, easiness_factor: 2.4, next_review_at: iso(2) },
  { id: 5, word: 'candid', reading: '/ˈkæn.dɪd/', meaning: '坦率的', pos: 'adj.', status: 'active', repetitions: 1, interval: 1, easiness_factor: 2.2, next_review_at: iso(-1) },
  { id: 6, word: 'inevitable', reading: '/ɪnˈev.ɪ.tə.bəl/', meaning: '不可避免的', pos: 'adj.', status: 'active', repetitions: 6, interval: 14, easiness_factor: 2.8, next_review_at: iso(14) }
]

function demoHeatmap(): Record<string, number> {
  const counts = [12, 20, 18, 3, 24, 20, 11]
  const out: Record<string, number> = {}
  const now = new Date()
  for (let i = 0; i < 7; i++) {
    const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (6 - i))
    const key = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0')
    out[key] = counts[i]
  }
  return out
}

export const demoDashboard: Dashboard = {
  online: false,
  languages: ['en'],
  activeLang: 'en',
  interfaceLang: 'zh',
  theme: 'dark',
  reviewedToday: 12,
  dailyTarget: 20,
  remaining: 8,
  accuracy: 0.86,
  streak: 12,
  heatmap: demoHeatmap(),
  words: DEMO_WORDS,
  totalWords: 4820,
  typeRates: {
    meaning: { total: 50, correct: 31 },
    spelling: { total: 30, correct: 17 },
    reading: { total: 24, correct: 17 }
  },
  pendingReview: 0
}

type Ctx = { port: string; token: string }

async function get<T>(ctx: Ctx, path: string): Promise<T> {
  const res = await fetch(`http://127.0.0.1:${ctx.port}${path}`, {
    headers: { Authorization: `Bearer ${ctx.token}` }
  })
  if (!res.ok) throw new Error(`${path} -> ${res.status}`)
  return (await res.json()) as T
}

function num(value: unknown, fallback = 0): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback
}

/**
 * Pulls the same endpoints the Flutter shell used. Any failure falls back to
 * demo data — the M0 goal is that the design renders exactly as approved, with
 * real numbers as soon as the Go service answers.
 */
export async function loadDashboard(ctx: Ctx | null): Promise<Dashboard> {
  if (!ctx) return demoDashboard
  try {
    const languages = await get<{ value: string[] }>(ctx, '/api/v1/config/languages')
    // The course language is config.active_lang, not "whichever language file
    // happens to be listed first": after another language is configured the
    // dashboard used to render that language's words under the current course.
    const cfg = await get<Record<string, unknown>>(ctx, '/api/v1/config').catch((): Record<string, unknown> => ({}))
    const activeLang =
      (typeof cfg['active_lang'] === 'string' && cfg['active_lang'] !== '' ? (cfg['active_lang'] as string) : '') ||
      languages.value[0] ||
      'en'
    const q = `?language=${activeLang}`

    // Every call may be missing on an older server; the empty-object fallbacks
    // are typed so the numeric readers below stay checkable.
    const none = (): Record<string, unknown> => ({})
    const [config, progress, today, streak, heatmap, words, diagnostics] = await Promise.all([
      Promise.resolve(cfg),
      get<Record<string, unknown>>(ctx, `/api/v1/quiz/progress${q}`).catch(none),
      get<Record<string, unknown>>(ctx, `/api/v1/quiz/today-stats${q}`).catch(none),
      get<Record<string, unknown>>(ctx, `/api/v1/stats/streak${q}`).catch(none),
      get<Record<string, number>>(ctx, `/api/v1/stats/heatmap?days=30&language=${activeLang}`).catch(
        (): Record<string, number> => ({})
      ),
      get<{ words: Word[]; total?: number }>(ctx, `/api/v1/words?language=${activeLang}&limit=60`).catch(
        (): { words: Word[]; total?: number } => ({ words: [] })
      ),
      get<Record<string, unknown>>(ctx, '/api/v1/stats/diagnostics?days=30').catch(none)
    ])

    const reviewed = num(today['reviewed'], num(progress['reviewed_today']))
    const correct = num(today['correct'])
    const accuracy = typeof today['accuracy'] === 'number' ? (today['accuracy'] as number) : reviewed ? correct / reviewed : 0
    const coverage = (diagnostics['coverage'] ?? {}) as Record<string, unknown>
    // daily_target=0 means "not configured" (the dev config uses it to skip the
    // lock screen); showing 0/0 as "100% done" would be a lie, so fall back to
    // the product default.
    const rawTarget = num(progress['daily_target'], 0) || num(config['daily_target'], 0)
    const dailyTarget = rawTarget > 0 ? rawTarget : 20
    // The server's own "remaining" is pool-aware and can be 0 while today's
    // count is 0 (empty review pool) — that would render as "100% done" on the
    // first screen of the day. The sidebar/hero goal is about today's count.
    const remaining = Math.max(0, dailyTarget - reviewed)

    return {
      online: true,
      languages: languages.value,
      activeLang,
      interfaceLang: String(config['interface_lang'] ?? 'zh'),
      theme: config['theme'] === 'vscode-light' || config['theme'] === 'light' ? 'light' : 'dark',
      reviewedToday: reviewed,
      dailyTarget,
      remaining,
      accuracy,
      streak: num(streak['streak']),
      heatmap,
      words: words.words,
      totalWords: num(words.total, words.words.length),
      typeRates: (diagnostics['type_rates'] ?? {}) as Record<string, TypeRate>,
      pendingReview: num(coverage['pending_review'])
    }
  } catch {
    return demoDashboard
  }
}

/** SM-2-ish strength used by the library column; purely presentational. */
export function strengthOf(word: Word): number {
  const reps = num(word.repetitions)
  const interval = num(word.interval)
  return Math.min(1, reps * 0.12 + Math.min(interval, 60) / 60 * 0.88)
}

export function daysUntil(iso: string | null | undefined): number | null {
  if (!iso) return null
  const target = new Date(iso)
  if (Number.isNaN(target.getTime())) return null
  const today = new Date()
  const a = Date.UTC(today.getFullYear(), today.getMonth(), today.getDate())
  const b = Date.UTC(target.getFullYear(), target.getMonth(), target.getDate())
  return Math.round((b - a) / 86400000)
}
async function jsonCall<T>(path: string, init: RequestInit): Promise<T> {
  const ctx = context
  if (!ctx) throw new Error('no backend')
  const res = await fetch(`http://127.0.0.1:${ctx.port}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${ctx.token}`,
      'Content-Type': 'application/json',
      ...(init.headers ?? {})
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

export type WordInput = {
  word: string
  reading?: string
  meaning?: string
  pos?: string
}

export function createWord(input: WordInput, language: string): Promise<Word> {
  return jsonCall<Word>('/api/v1/words', {
    method: 'POST',
    body: JSON.stringify({ ...input, language })
  })
}

export function updateWord(id: number, input: WordInput): Promise<Word> {
  return jsonCall<Word>(`/api/v1/words/${id}`, {
    method: 'PUT',
    body: JSON.stringify(input)
  })
}

export function deleteWord(id: number): Promise<unknown> {
  return jsonCall(`/api/v1/words/${id}`, { method: 'DELETE' })
}

/** Puts the word back into the review queue (clears its SM-2 progress). */
export function resetWord(id: number): Promise<unknown> {
  return jsonCall(`/api/v1/words/${id}/reset`, { method: 'POST' })
}
export type Settings = {
  activeLang: string
  interfaceLang: string
  explanationLang: string
  studentLevel: string
  dailyTarget: number
  dailyTimeTarget: number
  expandBatch: number
  sm2MaxInterval: number
  sessionBudget: number
  maxSlowRatio: number
  passiveEnabled: boolean
  passiveMin: number
  passiveMax: number
  cadenceDays: number
  cadenceCount: number
  maxPerSession: number
  aiRecommend: boolean
  escapeClicks: number
  escapePasswords: number
  minAccuracy: number
  autoExpand: boolean
  autoStart: boolean
  theme: string
  languages: string[]
  languageLocked: boolean
  aiBaseUrl: string
  aiModel: string
  aiConfigured: boolean
}
// Pure mapping so tests can pin the defaults without a live server.
export function mapSettings(cfg: Record<string, unknown>, ai: Record<string, unknown>): Settings {
  return {
    activeLang: String(cfg['active_lang'] ?? 'en'),
    interfaceLang: normaliseLang(String(cfg['interface_lang'] ?? 'zh')),
    explanationLang: String(cfg['ai_explanation_lang'] ?? ''),
    studentLevel: typeof cfg['student_level'] === 'string' ? cfg['student_level'] : '',
    dailyTarget: num(cfg['daily_target'], 20),
    dailyTimeTarget: num(cfg['daily_time_target'], 0),
    expandBatch: num(cfg['expand_batch_size'], 10),
    sm2MaxInterval: num(cfg['sm2_max_interval_days'], 180),
    sessionBudget: num(cfg['session_time_budget'], 0),
    maxSlowRatio: typeof cfg['max_slow_type_ratio'] === 'number' ? cfg['max_slow_type_ratio'] : 0.3,
    passiveEnabled: cfg['passive_enabled'] === true,
    passiveMin: num(cfg['passive_min_interval'], 25),
    passiveMax: num(cfg['passive_max_interval'], 45) || 45,
    // Older configs can carry an empty assignment block; fall back to the
    // product defaults instead of showing 0 in the form.
    cadenceDays: num((cfg['assignment'] as Record<string, unknown>)?.['cadence_days'], 7) || 7,
    cadenceCount: num((cfg['assignment'] as Record<string, unknown>)?.['cadence_count'], 3) || 3,
    maxPerSession: num((cfg['assignment'] as Record<string, unknown>)?.['max_per_session'], 1) || 1,
    aiRecommend: (cfg['assignment'] as Record<string, unknown>)?.['ai_recommend'] === true,
    escapeClicks: num(cfg['escape_click_limit'], 2),
    escapePasswords: num(cfg['escape_password_limit'], 3),
    minAccuracy: typeof cfg['min_accuracy'] === 'number' ? cfg['min_accuracy'] : 0.8,
    autoExpand: cfg['auto_expand_words'] === true,
    autoStart: cfg['auto_start'] === true,
    theme: String(cfg['theme'] ?? 'vs-dark'),
    languages: (cfg['languages'] as string[]) ?? [],
    languageLocked: cfg['language_locked'] === true,
    aiBaseUrl: String(ai['base_url'] ?? ''),
    aiModel: String(ai['model'] ?? ''),
    aiConfigured: ai['configured'] === true
  }
}

export async function loadSettings(): Promise<Settings> {
  const cfg = await jsonCall<Record<string, unknown>>('/api/v1/config', { method: 'GET' })
  const ai = await jsonCall<Record<string, unknown>>('/api/v1/config/ai', { method: 'GET' })
  return mapSettings(cfg, ai)
}
// The only way to change the course language once it is locked: the server
// re-runs initialisation for the new language instead of mixing vaults.
export function initCourseLanguage(language: string): Promise<unknown> {
  return jsonCall('/api/v1/config/language/init', { method: 'POST', body: JSON.stringify({ language }) })
}
export function saveAppConfig(patch: Record<string, unknown>): Promise<unknown> {
  return jsonCall('/api/v1/config', { method: 'PUT', body: JSON.stringify(patch) })
}
export function saveAIConfig(input: { baseUrl?: string; apiKey?: string; model?: string }): Promise<unknown> {
  return jsonCall('/api/v1/config/ai', { method: 'PUT', body: JSON.stringify(input) })
}

export type PlacementQuestion = {
  id: string
  word: string
  reading: string
  level: string
  options: string[]
}

export type PlacementResult = {
  estimated_level: string
  bands: Record<string, { correct: number; total: number }>
  daily_new_words: number
}

// 30 questions sampled across the installed graded packs; the server keeps the
// answer key, so the client never sees it.
export function startPlacement(): Promise<{ id: string; questions: PlacementQuestion[] }> {
  return jsonCall('/api/v1/quiz/placement/start', { method: 'POST', body: '{}' })
}

export function submitPlacement(
  id: string,
  answers: { id: string; answer: string }[]
): Promise<PlacementResult> {
  return jsonCall('/api/v1/quiz/placement/submit', { method: 'POST', body: JSON.stringify({ id, answers }) })
}
export type CapabilityLanguage = {
  code: string
  packs: string[]
  levels: string[]
  placement: boolean
  tts: boolean
  dict: boolean
  asr: boolean
  pronounce: boolean
  question_types: string[]
}

export type Capabilities = {
  active_language: string
  ai: boolean
  tts: boolean
  dict: boolean
  asr: boolean
  pronounce: boolean
  content: { root: string; packs: { id: string; language: string }[] }
  languages: Record<string, CapabilityLanguage>
}

export type Preset = {
  id: string
  name: string
  goal: string
  direction: string
  minutes: number
  daily_target: number
  daily_time_target: number
  session_time_budget: number
  max_slow_type_ratio: number
  content_pack?: string
  levels?: string[]
  available: boolean
  reason?: string
}

export function loadLanguages(): Promise<{ value: string[] }> {
  return jsonCall('/api/v1/config/languages', { method: 'GET' })
}

export function loadCapabilities(): Promise<Capabilities> {
  return jsonCall('/api/v1/capabilities', { method: 'GET' })
}

export function loadPresets(language: string): Promise<{ language: string; presets: Preset[] }> {
  return jsonCall('/api/v1/presets?language=' + encodeURIComponent(language), { method: 'GET' })
}

export function applyPreset(id: string, language: string): Promise<{
  preset: string
  language: string
  available: boolean
  applied: Record<string, unknown>
  skipped: string[]
}> {
  return jsonCall('/api/v1/config/preset', { method: 'PUT', body: JSON.stringify({ id, language }) })
}

export type LearnerProfile = {
  goal: string
  level: string
  daily_minutes: number
  preferences: string[]
  onboarding_done: boolean
  daily_target: number
  daily_time_target: number
  active_language: string
}

export function loadProfile(): Promise<LearnerProfile> {
  return jsonCall('/api/v1/profile', { method: 'GET' })
}

export function saveProfile(p: Partial<LearnerProfile>): Promise<LearnerProfile> {
  return jsonCall('/api/v1/profile', { method: 'PUT', body: JSON.stringify(p) })
}
