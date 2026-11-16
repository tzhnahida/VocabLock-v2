import RAW from './i18n.json'

export type Lang = 'zh' | 'en' | 'ja'

const table = RAW as Record<Lang, Record<string, string>>

/** Prototype string table (docs/design/app.html). Missing en/ja keys fall back to zh. */
export function t(lang: Lang, key: string): string {
  return table[lang]?.[key] ?? table.zh[key] ?? key
}

/**
 * The prototype hard-codes demo numbers into every sentence ("还剩 8 题").
 * Real data needs parameters, so the dynamic strings live here instead of in
 * the extracted table.
 */
export const dyn = {
  zh: {
    remain: (n: number, min: number) => `还剩 ${n} 题 · 约 ${min} 分钟`,
    unitQuestions: (n: number) => `/ ${n} 题`,
    done: (pct: number) => `已完成 ${pct}% · 预计还需 ${Math.max(1, Math.round((100 - pct) / 10))} 分钟`,
    weekTotal: (n: number) => `共 ${n} 题`,
    dueSub: (n: number) => `今天到期 ${n} 词`,
    streakSub: (days: number) => `本周 ${days}/7 天达标`,
    libCount: (n: number) => `${n} 词`,
    pager: (a: number, b: number, total: number) => `显示 ${a}–${b} / ${total}`,
    streakLine: (days: number, week: number) => `连续 ${days} 天 · 本周 ${week} 题`,
    dueToday: '今天',
    dueTomorrow: '明天',
    dueIn: (n: number) => `${n} 天后`,
    dueOverdue: '已到期',
    noWeak: '还没有足够的作答样本',
    today: '今日',
    offline: '后端未连接 · 显示演示数据',
    online: '已连接',
    quizTag: '词义选择',
    quizHint: '按 1–4 作答',
    correct: '正确',
    next: '下一题',
    loading: '加载中…',
    mastery: '熟练度'
  },
  en: {
    remain: (n: number, min: number) => `${n} left · about ${min} min`,
    unitQuestions: (n: number) => `/ ${n}`,
    done: (pct: number) => `${pct}% done · about ${Math.max(1, Math.round((100 - pct) / 10))} min left`,
    weekTotal: (n: number) => `${n} questions`,
    dueSub: (n: number) => `${n} due today`,
    streakSub: (days: number) => `${days}/7 days this week`,
    libCount: (n: number) => `${n} words`,
    pager: (a: number, b: number, total: number) => `Showing ${a}–${b} of ${total}`,
    streakLine: (days: number, week: number) => `${days}-day streak · ${week} this week`,
    dueToday: 'Today',
    dueTomorrow: 'Tomorrow',
    dueIn: (n: number) => `in ${n} days`,
    dueOverdue: 'Overdue',
    noWeak: 'Not enough answers yet',
    today: 'Today',
    offline: 'Backend offline · demo data',
    online: 'Connected',
    quizTag: 'Meaning',
    quizHint: 'Press 1–4 to answer',
    correct: 'Correct',
    next: 'Next',
    loading: 'Loading…',
    mastery: 'Strength'
  },
  ja: {
    remain: (n: number, min: number) => `残り ${n} 問 · 約 ${min} 分`,
    unitQuestions: (n: number) => `/ ${n} 問`,
    done: (pct: number) => `${pct}% 完了 · 残り約 ${Math.max(1, Math.round((100 - pct) / 10))} 分`,
    weekTotal: (n: number) => `計 ${n} 問`,
    dueSub: (n: number) => `今日は ${n} 語が期限`,
    streakSub: (days: number) => `今週 ${days}/7 日達成`,
    libCount: (n: number) => `${n} 語`,
    pager: (a: number, b: number, total: number) => `${a}–${b} / ${total} を表示`,
    streakLine: (days: number, week: number) => `${days} 日連続 · 今週 ${week} 問`,
    dueToday: '今日',
    dueTomorrow: '明日',
    dueIn: (n: number) => `${n} 日後`,
    dueOverdue: '期限切れ',
    noWeak: 'まだ十分な解答データがありません',
    today: '今日',
    offline: 'バックエンド未接続 · デモデータ',
    online: '接続済み',
    quizTag: '意味選択',
    quizHint: '1–4 で回答',
    correct: '正解',
    next: '次の問題',
    loading: '読み込み中…',
    mastery: '習熟度'
  }
} as const

export const langNative: Record<Lang, string> = { zh: '中文', en: 'English', ja: '日本語' }

/** Course (studied language) names, localized per UI language. */
export const courseName: Record<string, Record<Lang, string>> = {
  en: { zh: '英语', en: 'English', ja: '英語' },
  ja: { zh: '日语', en: 'Japanese', ja: '日本語' },
  zh: { zh: '中文', en: 'Chinese', ja: '中国語' },
  ko: { zh: '韩语', en: 'Korean', ja: '韓国語' }
}

export function courseLabel(code: string, lang: Lang): string {
  return courseName[code]?.[lang] ?? code.toUpperCase()
}

const typeNames: Record<string, Record<Lang, string>> = {
  choice: { zh: '词义选择', en: 'Meaning', ja: '意味選択' },
  meaning: { zh: '词义辨析', en: 'Meaning', ja: '意味弁別' },
  fill: { zh: '填空', en: 'Fill', ja: '穴埋め' },
  spelling: { zh: '拼写', en: 'Spelling', ja: '綴り' },
  reading: { zh: '阅读', en: 'Reading', ja: '読解' },
  reading_comp: { zh: '阅读理解', en: 'Comprehension', ja: '読解' },
  listening: { zh: '听力', en: 'Listening', ja: '聴解' },
  grammar: { zh: '语法', en: 'Grammar', ja: '文法' },
  read_word: { zh: '发音', en: 'Pronunciation', ja: '発音' },
  read_sentence: { zh: '朗读', en: 'Read aloud', ja: '音読' },
  dialogue_write: { zh: '造句', en: 'Writing', ja: '作文' },
  dialogue_speak: { zh: '口头造句', en: 'Speaking', ja: '発話' }
}

/** Question types are API identifiers; show a localized label when we know one. */
export function typeName(type: string, lang: Lang): string {
  return typeNames[type]?.[lang] ?? type.replace(/_/g, ' ')
}

/** "12 分钟前 / yesterday" for the recent list. */
export function ago(iso: string | null | undefined, lang: Lang): string {
  if (!iso) return '—'
  const then = new Date(iso).getTime()
  if (Number.isNaN(then)) return '—'
  const minutes = Math.max(0, Math.round((Date.now() - then) / 60000))
  const table = {
    zh: (m: number) => (m < 1 ? '刚刚' : m < 60 ? m + ' 分钟前' : m < 1440 ? Math.round(m / 60) + ' 小时前' : Math.round(m / 1440) + ' 天前'),
    en: (m: number) => (m < 1 ? 'just now' : m < 60 ? m + 'm ago' : m < 1440 ? Math.round(m / 60) + 'h ago' : Math.round(m / 1440) + 'd ago'),
    ja: (m: number) => (m < 1 ? 'たった今' : m < 60 ? m + ' 分前' : m < 1440 ? Math.round(m / 60) + ' 時間前' : Math.round(m / 1440) + ' 日前')
  }
  return table[lang](minutes)
}
