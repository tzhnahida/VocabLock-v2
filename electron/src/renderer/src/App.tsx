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
import Onboarding from './screens/Onboarding'
import { apiContext, configureApi, loadDashboard, loadProfile, unlockSystem, demoDashboard, type Dashboard } from './api'
import { courseLabel, type Lang } from './i18n'

export type Screen = 'home' | 'library' | 'quiz' | 'stats' | 'settings' | 'listening' | 'chat'

type RuntimeConfig = {
  locked: boolean
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
  // True only in the dedicated kiosk window; there the server owns the lock.
  const [onboarding, setOnboarding] = useState(false)

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

      let needsOnboarding = false
      if (loaded.online) {
        try {
          const profile = await loadProfile()
          needsOnboarding = !profile.onboarding_done
        } catch {
          // Mock/offline backends may not expose the profile endpoint.
          needsOnboarding = false
        }
      }

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
      }
      if (needsOnboarding) {
        // The service may have locked at startup because the vault already has
        // words; do not let the focus lock cover the first-run wizard.
        try {
          await unlockSystem()
        } catch {
          // Best effort; the wizard still works if the lock API is unavailable.
        }
      }
      setOnboarding(needsOnboarding)
      setReady(true)
    })()
    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => {
    document.documentElement.dataset.theme = theme
    document.body.dataset.screen = screen
    document.body.style.fontFamily = fonts[lang]
    document.documentElement.lang = lang === 'zh' ? 'zh-CN' : lang
    localStorage.setItem('vl-lang', lang)
    localStorage.setItem('vl-theme', theme)
  }, [theme, lang, screen])

  useEffect(() => {
    function onKey(e: KeyboardEvent): void {
      if (e.key === 'Escape' && screen === 'quiz') setScreen('home')
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [screen])

  useEffect(() => {
    window.vocablock.onLockState?.((value) => {
      // A fresh focus-lock always lands on the main screen; inner navigation
      // stays free afterwards.
      if (value) setScreen('home')
    })
  }, [])

  const go = useCallback((next: Screen) => {
    setScreen(next)
  }, [])
  const goQuiz = useCallback(() => {
    setScreen('quiz')
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

  if (onboarding) {
    return (
      <Onboarding
        lang={lang}
        activeLang={dash.activeLang}
        onLang={setLang}
        onDone={() => {
          setOnboarding(false)
          setScreen('home')
          void refresh()
        }}
      />
    )
  }

  return (
    <div className="app">
      <TitleBar
        lang={lang}
        theme={theme}
        onTheme={() => setTheme(theme === 'light' ? 'dark' : 'light')}
        crumb={`${courseLabel(dash.activeLang, lang)}${dash.online ? '' : ' · demo'}`}
        onLock={() => go('quiz')}
      />
      <div className="body">
        <Sidebar dash={dash} screen={screen} lang={lang} onNavigate={go} />
        <main>
          <section className="screen s-home">
            <Home dash={dash} lang={lang} onStart={goQuiz} onLibrary={() => go('library')} onStats={() => go('stats')} onLock={goQuiz} />
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
            <Listening dash={dash} lang={lang} onStudy={() => go('quiz')} />
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
    </div>
  )
}
