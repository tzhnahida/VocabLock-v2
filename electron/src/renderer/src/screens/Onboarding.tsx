import { useEffect, useState } from 'react'
import { courseLabel, type Lang } from '../i18n'
import { st } from '../strings'
import {
  applyPreset,
  initCourseLanguage,
  loadCapabilities,
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

const LANGS = ['ja', 'en', 'zh', 'ko'] as const
const GOALS = ['exam', 'conversation', 'work', 'interest'] as const
const PREFS = ['visual', 'auditory', 'kinesthetic', 'mixed'] as const
const LEVELS: Record<string, string[]> = {
  ja: ['N5', 'N4', 'N3', 'N2', 'N1'],
  en: ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'],
  zh: ['HSK1', 'HSK2', 'HSK3', 'HSK4', 'HSK5', 'HSK6'],
  ko: []
}

export default function Onboarding({ lang, activeLang, onLang, onDone }: Props) {
  const copy = st(lang, 'onboarding')
  const settings = st(lang, 'settings')
  const [step, setStep] = useState(0)
  const [caps, setCaps] = useState<Capabilities | null>(null)
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
      .then(setCaps)
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
      await saveProfile({
        goal,
        level,
        daily_minutes: minutes,
        preferences: prefs,
        onboarding_done: true
      })
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
    <div className="home settings">
      <div className="topline">
        <span>
          <b className="pagetitle">{copy.title}</b>
        </span>
        <span>{step + 1} / 3</span>
      </div>
      <div className="hintline">{copy.intro}</div>

      {step === 0 ? (
        <section className="card sect">
          <h3>{copy.interfaceLang}</h3>
          <div className="field">
            <select value={lang} onChange={(e) => onLang(e.target.value as Lang)}>
              <option value="zh">中文</option>
              <option value="en">English</option>
              <option value="ja">日本語</option>
            </select>
          </div>
          <h3>{copy.learningLang}</h3>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {LANGS.map((code) => {
              const cap = caps?.languages[code]
              const packs = cap ? cap.packs.length : 0
              const placement = cap ? cap.placement : false
              return (
                <button
                  key={code}
                  className="btn"
                  id={'onboard-lang-' + code}
                  style={learning === code ? { outline: '2px solid var(--accent)' } : undefined}
                  onClick={() => {
                    setLearning(code)
                    setLevel('')
                  }}
                >
                  {courseLabel(code, lang)}
                  <span className="hintline">
                    {' '}
                    {packs > 0 ? packs + ' pack(s)' : copy.noPack} · {placement ? 'placement' : 'self'}
                  </span>
                </button>
              )
            })}
          </div>
        </section>
      ) : null}

      {step === 1 ? (
        <section className="card sect">
          <h3>{copy.goal}</h3>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {GOALS.map((g) => (
              <button
                key={g}
                className="btn"
                style={goal === g ? { outline: '2px solid var(--accent)' } : undefined}
                onClick={() => setGoal(g)}
              >
                {copy.goals[g]}
              </button>
            ))}
          </div>
          <div className="field">
            <label>{copy.level}</label>
            <select id="onboard-level" value={level} onChange={(e) => setLevel(e.target.value)}>
              <option value="">{copy.levelAuto}</option>
              {levels.map((lv) => (
                <option key={lv} value={lv}>
                  {lv}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label htmlFor="onboard-minutes">{copy.minutes}</label>
            <input
              id="onboard-minutes"
              type="number"
              min={5}
              max={240}
              value={minutes}
              onChange={(e) => setMinutes(Number(e.target.value))}
            />
          </div>
          <h3>{copy.preferences}</h3>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {PREFS.map((p) => (
              <button
                key={p}
                className="btn"
                style={prefs.includes(p) ? { outline: '2px solid var(--accent)' } : undefined}
                onClick={() => togglePref(p)}
              >
                {copy.prefs[p]}
              </button>
            ))}
          </div>
        </section>
      ) : null}

      {step === 2 ? (
        <section className="card sect">
          <h3>{copy.plan}</h3>
          <div className="hintline">{copy.planHint}</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {presets.map((p) => (
              <label key={p.id} style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <input
                  type="radio"
                  name="onboard-plan"
                  value={p.id}
                  checked={plan === p.id}
                  disabled={!p.available}
                  onChange={() => setPlan(p.id)}
                />
                <span>
                  {settings.presetNames[p.id] ?? p.name}
                  {p.available ? '' : ' — ' + (p.reason ?? '')}
                </span>
              </label>
            ))}
          </div>
          <div className="hintline">
            {copy.summary(courseLabel(learning, lang), minutes, copy.goals[goal])}
          </div>
          {err ? <div className="hintline">{err}</div> : null}
        </section>
      ) : null}

      <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
        {step > 0 ? (
          <button className="btn ghost" disabled={busy} onClick={() => setStep(step - 1)}>
            {copy.back}
          </button>
        ) : null}
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
  )
}
