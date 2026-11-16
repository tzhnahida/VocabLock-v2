import { useState } from 'react'
import { t, dyn, type Lang } from '../i18n'
import type { Dashboard } from '../api'

type Props = { dash: Dashboard; lang: Lang; onExit: () => void }

export default function Lock({ dash, lang, onExit }: Props) {
  const word = dash.words[0] ?? { word: 'ubiquitous', meaning: '无处不在的', reading: '/juːˈbɪk.wɪ.təs/' }
  const [picked, setPicked] = useState<number | null>(null)
  const options = [
    { label: word.meaning ?? '—', correct: true },
    { label: '转瞬即逝的', correct: false },
    { label: '难以捉摸的', correct: false },
    { label: '必不可少的', correct: false }
  ]

  return (
    <div className="lock">
      <div className="locktop">
        <div className="brand">
          <div className="logo">V</div>
          VocabLock
          <span className="lockmode">{t(lang, 'lock.mode')}</span>
        </div>
        <div className="locktimer">
          <b>{dash.reviewedToday}/{dash.dailyTarget}</b>
          <span>{t(lang, 'lock.left')}</span>
        </div>
      </div>
      <div className="lockmain">
        <div className="lockcard">
          <div className="lockday">{t(lang, 'streak.title')}</div>
          <h1 className="word">{word.word}</h1>
          <div className="phon">
            <span className="play">
              <svg viewBox="0 0 24 24">
                <path d="M6 4l10 8-10 8z" fill="currentColor" />
              </svg>
            </span>
            {word.reading ?? ''}
          </div>
          <div className="opts">
            {options.map((opt, i) => (
              <div
                key={i}
                className={`opt${picked !== null && opt.correct ? ' good' : ''}`}
                onClick={() => setPicked(i)}
              >
                <span className="k">{i + 1}</span>
                <span>{opt.label}</span>
                {picked !== null && opt.correct ? <span className="mark">✓</span> : null}
              </div>
            ))}
          </div>
          <div className="lockprog">
            <div className="progress">
              <i style={{ width: `${dash.dailyTarget > 0 ? (dash.reviewedToday / dash.dailyTarget) * 100 : 0}%` }} />
            </div>
            <span>
              {dash.reviewedToday} / {dash.dailyTarget}
            </span>
          </div>
        </div>
      </div>
      <div className="lockfoot">
        <span>
          <kbd>Esc</kbd> <i onClick={onExit}>{t(lang, 'lock.exit')}</i>
        </span>
        <span>
          <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Q</kbd> <i>{t(lang, 'lock.emergency')}</i>
        </span>
        <span>{dyn[lang].online}</span>
      </div>
    </div>
  )
}
