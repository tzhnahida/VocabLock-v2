import { useEffect, useState } from 'react'
import { courseLabel, type Lang } from '../i18n'
import { st } from '../strings'
import {
  applyPreset,
  initCourseLanguage,
  loadCapabilities,
  loadLanguages,
  loadPresets,
  saveProfile,
  type Capabilities,
  type Preset
} from '../api'

type Props = {
  lang: Lang
  activeLang: string
  onLang: (lang: Lang) => void
  onDone: () => void
}

const BUILTIN = ['ja', 'en', 'zh', 'ko']
const GOALS = ['exam', 'conversation', 'work', 'interest'] as const
const PREFS = ['visual', 'auditory', 'kinesthetic', 'mixed'] as const
const LEVELS: Record<string, string[]> = {
  ja: ['N5', 'N4', 'N3', 'N2', 'N1'],
  en: ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'],
  zh: ['HSK1', 'HSK2', 'HSK3', 'HSK4', 'HSK5', 'HSK6'],
  ko: []
}

function labelFor(code: string, ui: Lang): string {
  return BUILTIN.includes(code) ? courseLabel(code, ui) : code.toUpperCase()
}

export default function Onboarding({ lang, activeLang, onLang, onDone }: Props) {
  const copy = st(lang, 'onboarding')
  const settings = st(lang, 'settings')
  const [step, setStep] = useState(0)
  const [caps, setCaps] = useState<Capabilities | null>(null)
  const [langs, setLangs] = useState<string[]>(BUILTIN)
  const [presets, setPresets] = useState<Preset[]>([])
  const [learning, setLearning] = useState(activeLang || 'ja')
  const [goal, setGoal] = useState<(typeof GOALS)[number]>('conversation')
  const [level, setLevel] = useState('')
  const [minutes, setMinutes] = useState(20)
  const [prefs, setPrefs] = useState<string[]>(['mixed'])
  const [plan, setPlan] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState('')

  useEffect(() => {
    void loadCapabilities()
      .then((c) => {
        setCaps(c)
        setLangs((prev) => Array.from(new Set([...prev, ...Object.keys(c.languages)])))
      })
      .catch(() => {})
    void loadLanguages()
      .then((r) => {
        if (Array.isArray(r.value)) setLangs((prev) => Array.from(new Set([...prev, ...r.value])))
      })
      .catch(() => {})
  }, [])

  useEffect(() => {
    void loadPresets(learning)
      .then((r) => {
        setPresets(r.presets)
        const first = r.presets.find((p) => p.available)
        setPlan(first ? first.id : '')
      })
      .catch(() => {})
  }, [learning])

  function togglePref(p: string): void {
    setPrefs((cur) => (cur.includes(p) ? cur.filter((x) => x !== p) : [...cur, p]))
  }

  async function finish(): Promise<void> {
    if (busy) return
    setBusy(true)
    setErr('')
    try {
      await saveProfile({ goal, level, daily_minutes: minutes, preferences: prefs, onboarding_done: true })
      if (learning !== activeLang) {
        try {
          await initCourseLanguage(learning)
        } catch {
          // The profile is already saved; language init can be retried in Settings.
        }
      }
      if (plan) {
        try {
          await applyPreset(plan, learning)
        } catch {
          // Preset is optional; settings still carry the profile.
        }
      }
      onDone()
    } catch (e) {
      setErr(copy.failed + (e instanceof Error ? e.message : String(e)))
    } finally {
      setBusy(false)
    }
  }

  const levels = LEVELS[learning] ?? []

  return (
    <div className="onboard-wrap">
      <div className="onboard-card">
        <div className="onboard-head">
          <div className="onboard-brand">
            <span className="logo">V</span> VocabLock
          </div>
          <div className="onboard-steps">
            {[0, 1, 2].map((i) => (
              <span key={i} className={i <= step ? 'on' : ''} />
            ))}
          </div>
        </div>

        <h1 className="onboard-title">{copy.title}</h1>
        <p className="onboard-sub">{copy.intro}</p>

        {step === 0 ? (
          <>
            <section className="onboard-section">
              <h3>{copy.interfaceLang}</h3>
              <select value={lang} onChange={(e) => onLang(e.target.value as Lang)}>
                <option value="zh">中文</option>
                <option value="en">English</option>
                <option value="ja">日本語</option>
              </select>
            </section>

            <section className="onboard-section">
              <h3>{copy.learningLang}</h3>
              <div className="option-grid">
                {langs.map((code) => {
                  const cap = caps?.languages[code]
                  const packs = cap ? cap.packs.length : 0
                  const placement = cap ? cap.placement : false
                  return (
                    <button
                      key={code}
                      id={'onboard-lang-' + code}
                      className={'option' + (learning === code ? ' on' : '')}
                      onClick={() => {
                        setLearning(code)
                        setLevel('')
                      }}
                    >
                      {labelFor(code, lang)}
                      <small>{settings.languageStatus(packs, placement)}</small>
                    </button>
                  )
                })}
              </div>
              <p className="onboard-note">{copy.moreLangs}</p>
            </section>
          </>
        ) : null}

        {step === 1 ? (
          <>
            <section className="onboard-section">
              <h3>{copy.goal}</h3>
              <div className="option-grid">
                {GOALS.map((g) => (
                  <button key={g} className={'option' + (goal === g ? ' on' : '')} onClick={() => setGoal(g)}>
                    {copy.goals[g]}
                  </button>
                ))}
              </div>
            </section>

            <section className="onboard-section">
              <h3>{copy.level}</h3>
              <select id="onboard-level" value={level} onChange={(e) => setLevel(e.target.value)}>
                <option value="">{copy.levelAuto}</option>
                {levels.map((lv) => (
                  <option key={lv} value={lv}>
                    {lv}
                  </option>
                ))}
              </select>
            </section>

            <section className="onboard-section">
              <h3>{copy.minutes}</h3>
              <input
                id="onboard-minutes"
                type="number"
                min={5}
                max={240}
                value={minutes}
                onChange={(e) => setMinutes(Number(e.target.value))}
              />
            </section>

            <section className="onboard-section">
              <h3>{copy.preferences}</h3>
              <div className="option-grid">
                {PREFS.map((p) => (
                  <button
                    key={p}
                    className={'option' + (prefs.includes(p) ? ' on' : '')}
                    onClick={() => togglePref(p)}
                  >
                    {copy.prefs[p]}
                  </button>
                ))}
              </div>
            </section>
          </>
        ) : null}

        {step === 2 ? (
          <section className="onboard-section">
            <h3>{copy.plan}</h3>
            <p className="onboard-note">{copy.planHint}</p>
            <div className="option-grid">
              {presets.map((p) => (
                <button
                  key={p.id}
                  className={'option' + (plan === p.id ? ' on' : '')}
                  disabled={!p.available}
                  onClick={() => setPlan(p.id)}
                >
                  {settings.presetNames[p.id] ?? p.name}
                  <small>{p.available ? copy.summary(labelFor(learning, lang), p.minutes, copy.goals[goal]) : p.reason}</small>
                </button>
              ))}
            </div>
            {err ? <p className="onboard-note">{err}</p> : null}
          </section>
        ) : null}

        <div className="onboard-actions">
          <div>
            {step > 0 ? (
              <button className="btn ghost" disabled={busy} onClick={() => setStep(step - 1)}>
                {copy.back}
              </button>
            ) : null}
          </div>
          <div>
            {step < 2 ? (
              <button className="btn" onClick={() => setStep(step + 1)}>
                {copy.next}
              </button>
            ) : (
              <button className="btn" id="onboard-finish" disabled={busy} onClick={() => void finish()}>
                {busy ? copy.saving : copy.finish}
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
