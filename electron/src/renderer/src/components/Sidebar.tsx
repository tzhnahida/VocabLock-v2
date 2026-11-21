import { t, dyn, langNative, type Lang } from '../i18n'
import type { Dashboard } from '../api'
import type { Screen } from '../App'

type Props = {
  dash: Dashboard
  screen: Screen
  lang: Lang
  onNavigate: (screen: Screen) => void
}

const ICONS = {
  learn: 'M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2zM22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z',
  words: 'M4 19.5A2.5 2.5 0 0 1 6.5 17H20M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z',
  audio: 'M3 18v-6a9 9 0 0 1 18 0v6M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3zM3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z',
  stats: 'M3 3v18h18M18 17V9M13 17V5M8 17v-3',
  settings: 'M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6',
  ai: 'M3 11h18v10H3zM12 3a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM12 7v4'
}

function NavIcon({ d }: { d: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
      <path d={d} />
    </svg>
  )
}

function weekTotal(heatmap: Record<string, number>): number {
  const now = new Date()
  let total = 0
  for (let i = 0; i < 7; i++) {
    const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i)
    const key = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0')
    total += heatmap[key] ?? 0
  }
  return total
}

export default function Sidebar({ dash, screen, lang, onNavigate }: Props) {
  const pct = dash.dailyTarget > 0 ? Math.min(1, dash.reviewedToday / dash.dailyTarget) : 0
  const dashLen = 94.2
  const remaining = Math.max(0, dash.dailyTarget - dash.reviewedToday)
  // ~40 s per question is the pace the design's "约 15 分钟 / 20 题" implies

  const items: Array<{ label: string; d: string; target?: Screen; disabled?: boolean }> = [
    { label: t(lang, 'nav.learn'), d: ICONS.learn, target: 'home' },
    { label: t(lang, 'nav.words'), d: ICONS.words, target: 'library' },
    { label: t(lang, 'nav.audio'), d: ICONS.audio, target: 'listening' },
    { label: t(lang, 'nav.stats'), d: ICONS.stats, target: 'stats' },
    { label: t(lang, 'nav.settings'), d: ICONS.settings, target: 'settings' }
  ]

  return (
    <aside className="sidebar">
      <div className="today">
        <div className="ring">
          <svg viewBox="0 0 38 38">
            <circle cx="19" cy="19" r="15" fill="none" stroke="var(--track)" strokeWidth="2.5" />
            <circle
              cx="19"
              cy="19"
              r="15"
              fill="none"
              stroke="var(--accent)"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeDasharray={`${pct * dashLen} ${dashLen}`}
            />
          </svg>
          <b>
            {dash.reviewedToday}/{dash.dailyTarget}
          </b>
        </div>
        <div>
          <div className="t1">{t(lang, 'today.title')}</div>
          <div className="t2">{remaining > 0 ? dyn[lang].remain(remaining) : dyn[lang].done(100)}</div>
        </div>
      </div>

      <nav>
        {items.map((item) => {
          const active = item.target === screen
          return (
            <div
              key={item.label}
              className={`nav${active ? ' on' : ''}${item.disabled ? ' disabled' : ''}`}
              title={item.disabled ? 'M2' : undefined}
              onClick={() => item.target && onNavigate(item.target)}
            >
              <NavIcon d={item.d} />
              <span>{item.label}</span>
            </div>
          )
        })}
        <div className="glabel">{t(lang, 'nav.more')}</div>
        <div
          className={`nav${screen === 'chat' ? ' on' : ''}`}
          onClick={() => onNavigate('chat')}
        >
          <NavIcon d={ICONS.ai} />
          <span>{t(lang, 'nav.ai')}</span>
        </div>
      </nav>

      <div className="sfoot">
        <div className="streak">
          <span className="dot" />
          <span>{dyn[lang].streakLine(dash.streak, weekTotal(dash.heatmap))}</span>
        </div>
        <div className="user">
          <div className="ava">{langNative[lang].slice(0, 1)}</div>
          <div>
            <div className="u1">{langNative[lang]}</div>
            <div className="u2">{`${dash.activeLang.toUpperCase()} · ${dyn[lang].libCount(dash.totalWords)}`}</div>
          </div>
        </div>
      </div>
    </aside>
  )
}