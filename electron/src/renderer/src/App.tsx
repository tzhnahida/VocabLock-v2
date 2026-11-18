import { useCallback, useEffect, useState } from 'react'
import TitleBar from './components/TitleBar'
import Sidebar from './components/Sidebar'
import Home from './screens/Home'
import Library from './screens/Library'
import Quiz from './screens/Quiz'
import Stats from './screens/Stats'
import Settings from './screens/Settings'
import Listening from './screens/Listening'
import Chat from './screens/Chat'
import Lock from './screens/Lock'
import { apiContext, configureApi, loadDashboard, demoDashboard, type Dashboard } from './api'
import { courseLabel, type Lang } from './i18n'

export type Screen = 'home' | 'library' | 'quiz' | 'stats' | 'settings' | 'listening' | 'chat'

type RuntimeConfig = {
  apiPort: string | null
  authToken: string | null
  screen: string
  theme: string | null
  lang: string | null
}

const fonts: Record<Lang, string> = {
  zh: '"Segoe UI Variable Text","Segoe UI","Microsoft YaHei UI",system-ui,sans-serif',
  en: '"Segoe UI Variable Text","Segoe UI",system-ui,sans-serif',
  ja: '"Segoe UI Variable Text","Segoe UI","Yu Gothic UI","Meiryo",system-ui,sans-serif'
}

function asLang(value: string | null | undefined): Lang | null {
  return value === 'zh' || value === 'en' || value === 'ja' ? value : null
}

export default function App() {
  const [ready, setReady] = useState(false)
  const [dash, setDash] = useState<Dashboard>(demoDashboard)
  const [screen, setScreen] = useState<Screen>('home')
  const [theme, setTheme] = useState<'light' | 'dark'>('dark')
  const [lang, setLang] = useState<Lang>('zh')
  const [locked, setLocked] = useState(false)
  // True only in the dedicated kiosk window; there the server owns the lock.
  const [lockWindow, setLockWindow] = useState(false)

  useEffect(() => {
    let cancelled = false
    void (async () => {
      const runtime: RuntimeConfig = await window.vocablock.runtime()
      const nextLang = asLang(runtime.lang) ?? asLang(localStorage.getItem('vl-lang')) ?? 'zh'
      const storedTheme = localStorage.getItem('vl-theme')
      const nextTheme =
        runtime.theme === 'light' || runtime.theme === 'dark'
          ? runtime.theme
          : storedTheme === 'light' || storedTheme === 'dark'
            ? storedTheme
            : 'dark'

      const ctx =
        runtime.apiPort && runtime.authToken
          ? { port: runtime.apiPort, token: runtime.authToken }
          : null
      configureApi(ctx)
      const loaded = await loadDashboard(ctx)
      if (cancelled) return

      setLang(nextLang)
      setTheme(nextTheme)
      setDash(loaded)
      if (
        runtime.screen === 'library' ||
        runtime.screen === 'quiz' ||
        runtime.screen === 'stats' ||
        runtime.screen === 'settings' ||
        runtime.screen === 'listening' ||
        runtime.screen === 'chat'
      ) {
        setScreen(runtime.screen)
      } else if (runtime.screen === 'lock') {
        setLockWindow(true)
        setLocked(true)
      }
      setReady(true)
    })()
    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => {
    document.documentElement.dataset.theme = theme
    document.body.dataset.screen = locked ? '' : screen
    // design.css shows the lock overlay through body.locked; without the class
    // the kiosk window renders an empty shell (sidebar only, black content).
    document.body.classList.toggle('locked', locked)
    document.body.style.fontFamily = fonts[lang]
    document.documentElement.lang = lang === 'zh' ? 'zh-CN' : lang
    localStorage.setItem('vl-lang', lang)
    localStorage.setItem('vl-theme', theme)
  }, [theme, lang, screen, locked])

  useEffect(() => {
    function onKey(e: KeyboardEvent): void {
      if (e.key === 'Escape') {
        // Inside the kiosk lock window the server owns the lock state, so
        // dismiss it through the bridge instead of only hiding the overlay.
        if (lockWindow) {
          window.vocablock.dismissLock()
          setLocked(false)
        } else if (locked) setLocked(false)
        else if (screen === 'quiz') setScreen('home')
      }
      if (!locked && e.key === 'l' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault()
        setLocked(true)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [locked, screen, lockWindow])

  const go = useCallback((next: Screen) => {
    setLocked(false)
    setScreen(next)
  }, [])

  // The lock window's "start studying" button tells the main window where to
  // go once the kiosk closes.
  useEffect(() => {
    window.vocablock.onNavigate?.((next) => {
      if (next === 'quiz') go('quiz')
    })
  }, [go])

  // Answering a question moves the daily counters, so the shell re-reads them
  // instead of keeping a stale hero/sidebar until the next launch.
  const refresh = useCallback(async () => {
    setDash(await loadDashboard(apiContext()))
  }, [])

  if (!ready) return <div className="boot">Loading…</div>

  return (
    <div className="app">
      <TitleBar
        lang={lang}
        theme={theme}
        onTheme={() => setTheme(theme === 'light' ? 'dark' : 'light')}
        crumb={`${courseLabel(dash.activeLang, lang)}${dash.online ? '' : ' · demo'}`}
        onLock={() => setLocked(true)}
      />
      <div className="body">
        <Sidebar dash={dash} screen={screen} lang={lang} onNavigate={go} />
        <main>
          <section className="screen s-home">
            <Home dash={dash} lang={lang} onStart={() => go('quiz')} onLibrary={() => go('library')} onStats={() => go('stats')} onLock={() => setLocked(true)} />
          </section>
          <section className="screen s-library">
            <Library dash={dash} lang={lang} onChanged={refresh} />
          </section>
          <section className="screen s-quiz">
            <Quiz dash={dash} lang={lang} onExit={() => go('home')} onAnswered={refresh} />
          </section>
          <section className="screen s-stats">
            <Stats dash={dash} lang={lang} />
          </section>
          <section className="screen s-chat">
            <Chat lang={lang} online={dash.online} />
          </section>
          <section className="screen s-listening">
            <Listening dash={dash} lang={lang} />
          </section>
          <section className="screen s-settings">
            <Settings
              lang={lang}
              theme={theme}
              onTheme={(next) => setTheme(next)}
              onLang={(next) => setLang(next)}
              onSaved={refresh}
            />
          </section>
        </main>
      </div>
      {locked && (
        <Lock
          dash={dash}
          lang={lang}
          onExit={() => setLocked(false)}
          onStudy={() => {
            if (lockWindow) {
              window.vocablock.startStudy()
            } else {
              setLocked(false)
              go('quiz')
            }
          }}
        />
      )}
    </div>
  )
}
