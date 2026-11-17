import { useEffect, useState } from 'react'
import { dyn, type Lang } from '../i18n'
import { passiveCard, passiveSubmit, type PassiveCard } from '../studyApi'

type Props = { lang: Lang }

const COPY = {
  zh: {
    title: '被动回忆',
    easy: '轻松',
    hard: '困难',
    forgot: '忘了',
    empty: '还没有可回忆的词',
    show: '显示答案',
    recalled: (n: number) => `已回忆 ${n}`
  },
  en: {
    title: 'Passive recall',
    easy: 'Easy',
    hard: 'Hard',
    forgot: 'Forgot',
    empty: 'No words to recall yet',
    show: 'Show answer',
    recalled: (n: number) => `${n} recalled`
  },
  ja: {
    title: '受動的な想起',
    easy: '余裕',
    hard: '難しい',
    forgot: '忘れた',
    empty: '想起できる単語がありません',
    show: '答えを見る',
    recalled: (n: number) => `${n} 件`
  }
} as const

export default function PassiveCard({ lang }: Props) {
  const copy = COPY[lang]
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
