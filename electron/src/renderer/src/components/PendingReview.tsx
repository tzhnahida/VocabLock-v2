import { useEffect, useState } from 'react'
import { dyn, type Lang } from '../i18n'
import { st } from '../strings'
import { acceptPendingWord, listPendingWords, rejectPendingWord, type PendingWord } from '../studyApi'

type Props = { lang: Lang; language: string; onAccepted: () => void }


type Draft = { reading: string; meaning: string; pos: string }

export default function PendingReview({ lang, language, onAccepted }: Props) {
  const copy = st(lang, 'pending')
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