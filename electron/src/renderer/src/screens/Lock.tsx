import { useState } from 'react'
import { t, dyn, type Lang } from '../i18n'
import type { Dashboard } from '../api'

type Props = { dash: Dashboard; lang: Lang; onExit: () => void; onStudy: () => void }

/**
 * The lock screen is a glance-at-a-word screen, not a quiz: the option row is
 * just a self-check. Options come from the real vault (never demo text), and
 * only words that actually have a meaning are used — a blank correct option
 * was possible when the first word's meaning was empty.
 */
export function buildOptions(words: Dashboard['words'], word: Dashboard['words'][number] | undefined) {
  const correct = (word?.meaning ?? '').trim()
  const seen = new Set<string>(correct ? [correct] : [])
  const distractors: string[] = []
  for (const w of words) {
    const m = (w.meaning ?? '').trim()
    if (!m || w.id === word?.id || seen.has(m)) continue
    seen.add(m)
    distractors.push(m)
    if (distractors.length === 3) break
  }
  const list = [...(correct ? [{ label: correct, correct: true }] : []), ...distractors.map((m) => ({ label: m, correct: false }))]
  for (let i = list.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[list[i], list[j]] = [list[j], list[i]]
  }
  return list
}

export default function Lock({ dash, lang, onExit, onStudy }: Props) {
  const studyable = dash.words.filter((w) => (w.meaning ?? '').trim() !== '')
  const word = studyable[0] ?? dash.words[0] ?? { word: 'ubiquitous', meaning: '无处不在的', reading: '/juːˈbɪk.wɪ.təs/' }
  const [picked, setPicked] = useState<number | null>(null)
  const [options] = useState(() => buildOptions(studyable, word))

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
          {options.length >= 2 ? (
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
          ) : null}
          <div className="lockstudy">
            <button className="btn" id="lock-study" onClick={onStudy}>
              {t(lang, 'lock.study')}
            </button>
            <span className="hintline">{t(lang, 'lock.studyHint')}</span>
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