import { t, type Lang } from '../i18n'

type Props = {
  lang: Lang
  theme: 'light' | 'dark'
  onTheme: () => void
  crumb: string
  onLock: () => void
}

// The interface language is deliberately changed in Settings (and saved)
// instead of one click in the title bar: a stray click should not flip the
// whole UI.
export default function TitleBar({ lang, theme, onTheme, crumb, onLock }: Props) {
  return (
    <div className="titlebar">
      <div className="brand">
        <div className="logo">V</div>
        VocabLock
        <span className="sep" />
        <span className="crumb">{crumb}</span>
      </div>
      <div className="tbright">
        <button className="iconbtn" onClick={onTheme} title={t(lang, 'theme.t')}>
          {theme === 'dark' ? (
            <svg className="moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round">
              <path d="M20 14.5A8.5 8.5 0 0 1 9.5 4 8.5 8.5 0 1 0 20 14.5z" />
            </svg>
          ) : (
            <svg className="sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round">
              <circle cx="12" cy="12" r="4" />
              <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
            </svg>
          )}
        </button>
        <button className="iconbtn" onClick={onLock} title={t(lang, 'lock.preview')}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
            <rect x="4" y="10" width="16" height="11" rx="2" />
            <path d="M8 10V7a4 4 0 0 1 8 0v3" />
          </svg>
        </button>
        <div className="tbdiv" />
        <div className="winbtns">
          <span onClick={() => window.vocablock.minimize()}>
            <svg viewBox="0 0 10 10">
              <path d="M1 5h8" stroke="currentColor" strokeWidth="1.2" />
            </svg>
          </span>
          <span onClick={() => window.vocablock.maximize()}>
            <svg viewBox="0 0 10 10">
              <rect x="1.5" y="1.5" width="7" height="7" fill="none" stroke="currentColor" strokeWidth="1.1" />
            </svg>
          </span>
          <span onClick={() => window.vocablock.close()}>
            <svg viewBox="0 0 10 10">
              <path d="M1.5 1.5l7 7M8.5 1.5l-7 7" stroke="currentColor" strokeWidth="1.1" />
            </svg>
          </span>
        </div>
      </div>
    </div>
  )
}
