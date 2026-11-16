import { useEffect, useMemo, useState } from 'react'
import { t, dyn, typeName, type Lang } from '../i18n'
import type { Dashboard } from '../api'

type Props = { dash: Dashboard; lang: Lang; onExit: () => void }

/**
 * M0 renders the approved question layout with real words from the course and
 * local judging. The full submit/SM-2 loop arrives with the quiz API port;
 * see docs/STATUS.md for the boundary.
 */
export default function Quiz({ dash, lang, onExit }: Props) {
  const pool = dash.words.length > 0 ? dash.words : [{ id: 0, word: 'ubiquitous', meaning: '无处不在的', reading: '/juːˈbɪk.wɪ.təs/', pos: 'adj.' } as any]
  const [index, setIndex] = useState(0)
  const [picked, setPicked] = useState<number | null>(null)

  const question = pool[index % pool.length]
  const options = useMemo(() => {
    const base = question.meaning ?? '—'
    const others = pool.filter((w) => w.id !== question.id && w.meaning).slice(0, 3).map((w) => w.meaning as string)
    while (others.length < 3) others.push(['转瞬即逝的', '必不可少的', '难以捉摸的'][others.length % 3])
    const all = [base, ...others].map((label, i) => ({ label, correct: i === 0 }))
    // deterministic shuffle so options are not always in the same position
    const seed = (question.id * 7 + index) % 4
    return all.map((_, i) => all[(i + seed) % all.length])
  }, [question, pool, index])

  const correctIndex = options.findIndex((o) => o.correct)

  useEffect(() => {
    function onKey(e: KeyboardEvent): void {
      if (e.key >= '1' && e.key <= '4') setPicked(Number(e.key) - 1)
      if (e.key === ' ' && picked !== null) {
        e.preventDefault()
        next()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  })

  function next(): void {
    setPicked(null)
    setIndex((i) => i + 1)
  }

  const progress = dash.dailyTarget > 0 ? Math.min(1, dash.reviewedToday / dash.dailyTarget) : 0

  return (
    <div className="content">
      <div>
        <div className="topline">
          <span>
            <a className="link" onClick={onExit}>
              {t(lang, 'quiz.back')}
            </a>{' '}
            · <b>{t(lang, 'top.line')}</b>
          </span>
          <span>{`${Math.round(dash.accuracy * 100)}%`}</span>
        </div>
        <div className="progress">
          <i style={{ width: `${progress * 100}%` }} />
        </div>

        <section className="card qcard">
          <div className="qhead">
            <span className="tag">{dyn[lang].quizTag}</span>
            <span className="hint">{dyn[lang].quizHint}</span>
          </div>
          <h1 className="word">{question.word}</h1>
          <div className="phon">
            <span className="play">
              <svg viewBox="0 0 24 24">
                <path d="M6 4l10 8-10 8z" fill="currentColor" />
              </svg>
            </span>
            {question.reading ?? ''} {question.pos ? <span className="pos">{question.pos}</span> : null}
          </div>
          {/* The prototype shows an example sentence with the word blanked out.
              Course data has no example sentences yet, so showing anything here
              would either repeat the answer or invent one (see STATUS.md). */}
          <div className="opts">
            {options.map((opt, i) => {
              const answered = picked !== null
              const cls = `opt${answered && i === correctIndex ? ' good' : ''}${answered && picked === i && picked !== correctIndex ? ' bad' : ''}`
              return (
                <div key={i} className={cls} onClick={() => setPicked(i)}>
                  <span className="k">{i + 1}</span>
                  <span>{opt.label}</span>
                  {answered && i === correctIndex ? <span className="mark">✓</span> : null}
                </div>
              )
            })}
          </div>
          {picked !== null ? (
            <div className="fb">
              <span className="ic">{picked === correctIndex ? '✓' : '×'}</span>
              <div>
                <div className="l1">{picked === correctIndex ? dyn[lang].correct : t(lang, 'fb.t')}</div>
                <div className="l2">
                  {question.word} {question.reading ?? ''} — {question.meaning ?? ''}
                </div>
              </div>
            </div>
          ) : null}
          <div className="qfoot">
            <div className="keys">
              <span>
                <kbd>Esc</kbd> <i>{t(lang, 'keys.exit')}</i>
              </span>
              <span>
                <kbd>1</kbd>–<kbd>4</kbd> <i>{t(lang, 'keys.choose')}</i>
              </span>
              <span>
                <kbd>R</kbd> <i>{t(lang, 'keys.replay')}</i>
              </span>
            </div>
            <button className="btn" onClick={next} disabled={picked === null}>
              <i>{t(lang, 'next')}</i>
              <kbd>Space</kbd>
            </button>
          </div>
        </section>
      </div>

      <div className="rail">
        <section className="card rcard">
          <div className="rh">
            <span>{t(lang, 'rail.today')}</span>
            <span>{t(lang, 'rail.goal')}</span>
          </div>
          <div className="big">
            <b>{dash.reviewedToday}</b>
            <span>{`/ ${dash.dailyTarget}`}</span>
          </div>
          <div className="rbar">
            <i style={{ width: `${progress * 100}%` }} />
          </div>
        </section>
        <section className="card rcard">
          <div className="rh">
            <span>{t(lang, 'rail.round')}</span>
            <span>
              {index + 1} / {pool.length}
            </span>
          </div>
          <div className="dots">
            {Array.from({ length: Math.min(20, pool.length) }).map((_, i) => (
              <i key={i} className={i < index ? 'd' : i === index ? 'c' : undefined} />
            ))}
          </div>
        </section>
        <section className="card rcard">
          <div className="rh">
            <span>{t(lang, 'rail.weak')}</span>
            <span>{t(lang, 'rail.week')}</span>
          </div>
          <div className="weak">
            {Object.entries(dash.typeRates)
              .map(([type, rate]) => ({ type, acc: rate.total > 0 ? rate.correct / rate.total : 0 }))
              .sort((a, b) => a.acc - b.acc)
              .slice(0, 3)
              .map((w) => (
                <div className="wrow" key={w.type}>
                  <div className="wl">
                    <span>{typeName(w.type, lang)}</span>
                    <span>{Math.round(w.acc * 100)}%</span>
                  </div>
                  <div className="wbar">
                    <i style={{ width: `${Math.round(w.acc * 100)}%` }} />
                  </div>
                </div>
              ))}
          </div>
        </section>
        <div className="hintbox">
          <kbd>Ctrl</kbd>+<kbd>K</kbd> <span>{t(lang, 'hint.cmd')}</span> · <kbd>Ctrl</kbd>+<kbd>L</kbd> <span>{t(lang, 'hint.lock')}</span>
        </div>
      </div>
    </div>
  )
}
