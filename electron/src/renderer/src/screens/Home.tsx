import { t, dyn, typeName, ago, type Lang } from '../i18n'
import { daysUntil, type Dashboard } from '../api'
import AssignmentCard from '../components/Assignment'

type Props = {
  dash: Dashboard
  lang: Lang
  onStart: () => void
  onLibrary: () => void
  onStats: () => void
  onLock: () => void
}

function lastSeven(heatmap: Record<string, number>): Array<{ key: string; count: number; weekday: number }> {
  const out: Array<{ key: string; count: number; weekday: number }> = []
  const now = new Date()
  for (let i = 6; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i)
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
    out.push({ key, count: heatmap[key] ?? 0, weekday: ((d.getDay() + 6) % 7) + 1 })
  }
  return out
}

function greeting(lang: Lang): string {
  const hour = new Date().getHours()
  const slot = hour < 6 ? 0 : hour < 12 ? 1 : hour < 18 ? 2 : 3
  const words = { zh: ['夜深了', '早上好', '下午好', '晚上好'], en: ['Late night', 'Good morning', 'Good afternoon', 'Good evening'], ja: ['こんばんは', 'おはようございます', 'こんにちは', 'こんばんは'] }
  return words[lang][slot]
}

function dateLine(lang: Lang): string {
  const d = new Date()
  const wd = ((d.getDay() + 6) % 7) + 1
  const wdLabel = t(lang, `day.${wd}`)
  if (lang === 'zh') return `${d.getMonth() + 1} 月 ${d.getDate()} 日 · ${wdLabel}`
  if (lang === 'ja') return `${d.getMonth() + 1}月${d.getDate()}日(${wdLabel.replace('曜日', '')})`
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) + ` · ${wdLabel}`
}

export default function Home({ dash, lang, onStart, onLibrary, onStats, onLock }: Props) {
  const pct = dash.dailyTarget > 0 ? Math.min(1, dash.reviewedToday / dash.dailyTarget) : 0
  const week = lastSeven(dash.heatmap)
  const weekTotal = week.reduce((sum, d) => sum + d.count, 0)
  const max = Math.max(1, ...week.map((d) => d.count))
  const recent = dash.words.slice(0, 3)
  const dueCount = dash.words.filter((w) => {
    const d = daysUntil(w.next_review_at)
    return d !== null && d <= 0
  }).length
  const weak = Object.entries(dash.typeRates)
    .map(([type, rate]) => ({ type, acc: rate.total > 0 ? rate.correct / rate.total : 0 }))
    .sort((a, b) => a.acc - b.acc)
    .slice(0, 3)

  return (
    <div className="home">
      <div className="topline greetrow">
        <span className="greet">{greeting(lang)}</span>
        <span>{dateLine(lang)}</span>
      </div>

      <div className="hgrid">
        <div className="col">
          <section className="card hero">
            <div>
              <div className="eyebrow">{t(lang, 'home.goal')}</div>
              <div className="hbig">
                <b>{dash.reviewedToday}</b>
                <span>{dyn[lang].unitQuestions(dash.dailyTarget)}</span>
              </div>
              <div className="note">{dyn[lang].done(Math.round(pct * 100))}</div>
              <button className="btn" onClick={onStart}>
                <span>{t(lang, 'home.start')}</span>
                <kbd>Enter</kbd>
              </button>
            </div>
            <div className="ring-lg">
              <svg viewBox="0 0 104 104">
                <circle cx="52" cy="52" r="44" fill="none" stroke="var(--track)" strokeWidth="3" />
                <circle
                  cx="52"
                  cy="52"
                  r="44"
                  fill="none"
                  stroke="var(--accent)"
                  strokeWidth="3"
                  strokeLinecap="round"
                  strokeDasharray={`${pct * 276.5} 276.5`}
                />
              </svg>
              <b>{Math.round(pct * 100)}%</b>
            </div>
          </section>

          <section className="card chart">
            <div className="rh">
              <span>{t(lang, 'chart.title')}</span>
              <span>{dyn[lang].weekTotal(weekTotal)}</span>
            </div>
            <div className="bars">
              {week.map((d, i) => (
                <div key={d.key} className={`bar${i === week.length - 1 ? ' today' : ''}`}>
                  <i style={{ height: `${Math.max(6, Math.round((d.count / max) * 96))}px` }} />
                  <em>{t(lang, `day.${d.weekday}`)}</em>
                </div>
              ))}
            </div>
          </section>

          <section className="card recent">
            <div className="rh">
              <span>{t(lang, 'recent.title')}</span>
              <a className="link" onClick={onLibrary}>
                {t(lang, 'recent.all')}
              </a>
            </div>
            {recent.length === 0 ? (
              <div className="emptystate">{t(lang, 'recent.title')} · —</div>
            ) : (
              recent.map((w) => {
                const d = daysUntil(w.next_review_at)
                const status = d !== null && d <= 0 ? 'due' : (w.repetitions ?? 0) >= 4 && (w.interval ?? 0) > 14 ? 'mastered' : 'learning'
                return (
                  <div className="rrow" key={w.id}>
                    <b>{w.word}</b>
                    <span className={`chip ${status}`}>{t(lang, status === 'due' ? 'st.due' : status === 'mastered' ? 'st.mastered' : 'st.learning')}</span>
                    <span className="when">{ago(w.last_review_at, lang)}</span>
                  </div>
                )
              })
            )}
          </section>
        </div>

        <div className="col">
          <section className="card c-streak">
            <div className="rh">
              <span>{t(lang, 'streak.title')}</span>
              <span>{dyn[lang].streakSub(week.filter((d) => d.count > 0).length)}</span>
            </div>
            <div className="hbig sm">
              <b>{dash.streak}</b>
              <span>{t(lang, 'streak.unit')}</span>
            </div>
            <div className="weekdots">
              {week.map((d) => (
                <i key={d.key} className={d.count > 0 ? 'd' : undefined} />
              ))}
            </div>
          </section>

          <section className="card c-due">
            <div className="rh">
              <span>{t(lang, 'due.title')}</span>
              <a className="link" onClick={onStart}>
                {t(lang, 'due.go')}
              </a>
            </div>
            <div className="hbig sm">
              <b>{dueCount}</b>
              <span>{t(lang, 'due.unit')}</span>
            </div>
            <div className="note">{dyn[lang].dueSub(dueCount)}</div>
          </section>

          <section className="card c-weak">
            <div className="rh">
              <span>{t(lang, 'rail.weak')}</span>
              <span>{t(lang, 'rail.week')}</span>
            </div>
            <div className="weak">
              {weak.length === 0 ? (
                <div className="emptystate">{dyn[lang].noWeak}</div>
              ) : (
                weak.map((w) => (
                  <div className="wrow" key={w.type}>
                    <div className="wl">
                      <span>{typeName(w.type, lang)}</span>
                      <span>{Math.round(w.acc * 100)}%</span>
                    </div>
                    <div className="wbar">
                      <i style={{ width: `${Math.round(w.acc * 100)}%` }} />
                    </div>
                  </div>
                ))
              )}
            </div>
          </section>

          <AssignmentCard lang={lang} language={dash.activeLang} />

          <section className="card c-quick">
            <div className="rh">
              <span>{t(lang, 'quick.title')}</span>
            </div>
            <div className="qgrid">
              <button className="qbtn" onClick={onLibrary}>
                {t(lang, 'quick.import')}
              </button>
              <button className="qbtn" onClick={onLibrary}>
                {t(lang, 'quick.ai')}
              </button>
              <button className="qbtn" onClick={onLock}>
                {t(lang, 'quick.lock')}
              </button>
              <button className="qbtn" onClick={onStats}>
                {t(lang, 'quick.stats')}
              </button>
            </div>
          </section>
        </div>
      </div>
    </div>
  )
}
