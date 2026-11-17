import { useEffect, useState } from 'react'
import { dyn, type Lang } from '../i18n'
import { st } from '../strings'
import { passiveCard, passiveSubmit, type PassiveCard } from '../studyApi'

type Props = { lang: Lang }


export default function PassiveCard({ lang }: Props) {
  const copy = st(lang, 'passive')
  const [card, setCard] = useState<PassiveCard | null>(null)
  const [revealed, setRevealed] = useState(false)
  const [busy, setBusy] = useState(false)
  const [done, setDone] = useState(0)

  useEffect(() => {
    void passiveCard()
      .then(setCard)
      .catch(() => undefined)
  }, [])

  async function rate(recall: 'easy' | 'hard' | 'forgot'): Promise<void> {
    if (!card || card.word_id === 0 || busy) return
    setBusy(true)
    try {
      await passiveSubmit(card.word_id, recall)
      setDone((n) => n + 1)
      setRevealed(false)
      setCard(await passiveCard())
    } catch {
      /* keep the current card on failure */
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="card c-passive">
      <div className="rh">
        <span>{copy.title}</span>
        <span className="muted">{done > 0 ? copy.recalled(done) : ''}</span>
      </div>
      {card === null ? (
        <div className="note">{dyn[lang].loading}</div>
      ) : card.word_id === 0 ? (
        <div className="emptystate">{copy.empty}</div>
      ) : (
        <>
          <div className="passive-word">{card.word}</div>
          {revealed ? (
            <div className="note">
              {card.reading} · {card.meaning}
            </div>
          ) : (
            <button className="btn ghost" onClick={() => setRevealed(true)}>
              {copy.show}
            </button>
          )}
          <div className="passive-actions">
            <button className="btn ghost" disabled={busy} onClick={() => void rate('easy')}>
              {copy.easy}
            </button>
            <button className="btn ghost" disabled={busy} onClick={() => void rate('hard')}>
              {copy.hard}
            </button>
            <button className="btn ghost" disabled={busy} onClick={() => void rate('forgot')}>
              {copy.forgot}
            </button>
          </div>
        </>
      )}
    </section>
  )
}