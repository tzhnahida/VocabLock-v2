import { useEffect, useState } from 'react'
import { dyn, type Lang } from '../i18n'
import { acceptPendingWord, listPendingWords, rejectPendingWord, type PendingWord } from '../studyApi'

type Props = { lang: Lang; language: string; onAccepted: () => void }

const COPY = {
  zh: {
    title: '待审词',
    empty: '没有待审的词',
    hint: '补全读音、词性、释义后采纳；AI 会补齐其余字段',
    accept: '采纳',
    reject: '驳回',
    reading: '读音',
    meaning: '释义',
    pos: '词性',
    required: '读音、词性、释义都不能为空'
  },
  en: {
    title: 'Pending review',
    empty: 'Nothing pending',
    hint: 'Fill reading, part of speech and meaning, then accept — AI fills the rest',
    accept: 'Accept',
    reject: 'Reject',
    reading: 'Reading',
    meaning: 'Meaning',
    pos: 'POS',
    required: 'Reading, POS and meaning are required'
  },
  ja: {
    title: '承認待ち',
    empty: '承認待ちの単語はありません',
    hint: '読み・品詞・意味を入れて承認すると、AI が残りを補完します',
    accept: '承認',
    reject: '却下',
    reading: '読み',
    meaning: '意味',
    pos: '品詞',
    required: '読み・品詞・意味は必須です'
  }
} as const

type Draft = { reading: string; meaning: string; pos: string }

export default function PendingReview({ lang, language, onAccepted }: Props) {
  const copy = COPY[lang]
  const [words, setWords] = useState<PendingWord[] | null>(null)
  const [drafts, setDrafts] = useState<Record<number, Draft>>({})
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  async function load(): Promise<void> {
    try {
      const res = await listPendingWords(language)
      setWords(res.words ?? [])
      const next: Record<number, Draft> = {}
      for (const w of res.words ?? []) {
        next[w.id] = { reading: w.reading ?? '', meaning: w.meaning ?? '', pos: w.pos ?? '' }
      }
      setDrafts(next)
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e))
    }
  }

  useEffect(() => {
    void load()
    // eslint-disable-next-line react-hooks/exhaustive-deps -- reload when the course changes
  }, [language])

  async function accept(word: PendingWord): Promise<void> {
    const draft = drafts[word.id]
    if (!draft) return
    if (!draft.reading.trim() || !draft.meaning.trim() || !draft.pos.trim()) {
      setError(copy.required)
      return
    }
    setBusy(true)
    setError('')
    try {
      await acceptPendingWord(word.id, { reading: draft.reading.trim(), meaning: draft.meaning.trim(), pos: draft.pos.trim() })
      onAccepted()
      await load()
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e))
    } finally {
      setBusy(false)
    }
  }

  async function reject(word: PendingWord): Promise<void> {
    setBusy(true)
    try {
      await rejectPendingWord(word.id)
      await load()
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e))
    } finally {
      setBusy(false)
    }
  }

  const set = (id: number, key: keyof Draft, value: string): void =>
    setDrafts((prev) => ({ ...prev, [id]: { ...(prev[id] ?? { reading: '', meaning: '', pos: '' }), [key]: value } }))

  return (
    <section className="card c-pending">
      <div className="rh">
        <span>{copy.title}</span>
        <span className="muted">{words ? words.length : dyn[lang].loading}</span>
      </div>
      <div className="note">{copy.hint}</div>
      {words && words.length === 0 ? <div className="emptystate">{copy.empty}</div> : null}
      {(words ?? []).map((w) => {
        const draft = drafts[w.id] ?? { reading: '', meaning: '', pos: '' }
        return (
          <div className="pending-row" key={w.id}>
            <div className="pending-word">{w.word}</div>
            <div className="pending-fields">
              <input value={draft.reading} placeholder={copy.reading} onChange={(e) => set(w.id, 'reading', e.target.value)} />
              <input value={draft.pos} placeholder={copy.pos} onChange={(e) => set(w.id, 'pos', e.target.value)} />
              <input value={draft.meaning} placeholder={copy.meaning} onChange={(e) => set(w.id, 'meaning', e.target.value)} />
            </div>
            <div className="pending-actions">
              <button className="btn" disabled={busy} onClick={() => void accept(w)}>
                {copy.accept}
              </button>
              <button className="btn ghost" disabled={busy} onClick={() => void reject(w)}>
                {copy.reject}
              </button>
            </div>
          </div>
        )
      })}
      {error ? <div className="note err">{error}</div> : null}
    </section>
  )
}
