import { useEffect, useState } from 'react'
import { courseLabel, langNative, normaliseLang, type Lang } from '../i18n'
import { st } from '../strings'
import { initCourseLanguage, loadSettings, saveAIConfig, saveAppConfig, type Settings as SettingsData } from '../api'

type Props = {
  lang: Lang
  theme: 'light' | 'dark'
  onTheme: (theme: 'light' | 'dark') => void
  onLang: (lang: Lang) => void
  onSaved: () => void
}


export default function Settings({ lang, theme, onTheme, onLang, onSaved }: Props) {
  const copy = st(lang, 'settings')
  const [data, setData] = useState<SettingsData | null>(null)
  const [apiKey, setApiKey] = useState('')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const [failed, setFailed] = useState(false)
  const [switchOpen, setSwitchOpen] = useState(false)
  const [switchLang, setSwitchLang] = useState('')
  const [switching, setSwitching] = useState(false)

  useEffect(() => {
    void loadSettings()
      .then(setData)
      .catch((e) => {
        setFailed(true)
        setMessage(copy.failed + (e instanceof Error ? e.message : String(e)))
      })
  }, [copy.failed])

  async function save(): Promise<void> {
    if (!data || busy) return
    setBusy(true)
    setMessage('')
    setFailed(false)
    try {
      await saveAppConfig({
        active_lang: data.activeLang,
        interface_lang: data.interfaceLang,
        daily_target: data.dailyTarget,
        daily_time_target: data.dailyTimeTarget,
        student_level: data.studentLevel,
        min_accuracy: data.minAccuracy,
        ai_explanation_lang: data.explanationLang,
        auto_expand_words: data.autoExpand,
        expand_batch_size: data.expandBatch,
        sm2_max_interval_days: data.sm2MaxInterval,
        session_time_budget: data.sessionBudget,
        max_slow_type_ratio: data.maxSlowRatio,
        passive_enabled: data.passiveEnabled,
        passive_min_interval: data.passiveMin,
        passive_max_interval: data.passiveMax,
        assignment: {
          cadence_days: data.cadenceDays,
          cadence_count: data.cadenceCount,
          max_per_session: data.maxPerSession,
          ai_recommend: data.aiRecommend
        },
        escape_click_limit: data.escapeClicks,
        escape_password_limit: data.escapePasswords,
        auto_start: data.autoStart,
        theme: theme === 'light' ? 'vscode-light' : 'vs-dark'
      })
      if (apiKey.trim() !== '') {
        await saveAIConfig({ baseUrl: data.aiBaseUrl, model: data.aiModel, apiKey: apiKey.trim() })
        setApiKey('')
      } else if (data.aiBaseUrl !== '' || data.aiModel !== '') {
        await saveAIConfig({ baseUrl: data.aiBaseUrl, model: data.aiModel })
      }
      setMessage(copy.saved)
      if (data.interfaceLang !== lang) onLang(normaliseLang(data.interfaceLang))
      onSaved()
    } catch (e) {
      setFailed(true)
      setMessage(copy.failed + (e instanceof Error ? e.message : String(e)))
    } finally {
      setBusy(false)
    }
  }

  if (!data) {
    return <div className="home settings">{message || '…'}</div>
  }

  return (
    <div className="home settings">
      <div className="topline">
        <span>
          <b className="pagetitle">{copy.title}</b>
        </span>
        <span>{data.aiConfigured ? copy.configured : copy.notConfigured}</span>
      </div>

      <div className="hgrid">
        <div className="col">
          <section className="card sect">
            <h3>{copy.learning}</h3>
            <div className="grid2">
              <div className="field">
                <label>{copy.course}</label>
                <select
                  id="set-course"
                  value={data.activeLang}
                  disabled={data.languageLocked}
                  onChange={(e) => setData({ ...data, activeLang: e.target.value })}
                >
                  {data.languages.map((code) => (
                    <option key={code} value={code}>
                      {courseLabel(code, lang)}
                    </option>
                  ))}
                </select>
                {data.languageLocked ? (
                  <div className="hintline">
                    {copy.courseLocked}{' '}
                    <button
                      className="btn ghost"
                      id="set-switch-language"
                      onClick={() => {
                        setSwitchLang(data.activeLang)
                        setSwitchOpen(true)
                      }}
                    >
                      {copy.switchCourse}
                    </button>
                  </div>
                ) : null}
              </div>
              <div className="field">
                <label>{copy.dailyTarget}</label>
                <input
                  id="set-daily-target"
                  type="number"
                  min={1}
                  max={200}
                  value={data.dailyTarget}
                  onChange={(e) => setData({ ...data, dailyTarget: Number(e.target.value) })}
                />
              </div>
              <div className="field">
                <label>{copy.dailyTimeTarget}</label>
                <input
                  id="set-daily-time"
                  type="number"
                  min={0}
                  max={600}
                  value={data.dailyTimeTarget}
                  onChange={(e) => setData({ ...data, dailyTimeTarget: Number(e.target.value) })}
                />
              </div>
              <div className="field">
                <label>{copy.expandBatch}</label>
                <input
                  id="set-expand-batch"
                  type="number"
                  min={1}
                  max={50}
                  value={data.expandBatch}
                  onChange={(e) => setData({ ...data, expandBatch: Number(e.target.value) })}
                />
              </div>
              <div className="field">
                <label>{copy.sm2MaxInterval}</label>
                <input
                  id="set-sm2-max"
                  type="number"
                  min={30}
                  max={365}
                  value={data.sm2MaxInterval}
                  onChange={(e) => setData({ ...data, sm2MaxInterval: Number(e.target.value) })}
                />
              </div>
              <div className="field">
                <label>{copy.sessionBudget}</label>
                <input
                  id="set-session-budget"
                  type="number"
                  min={0}
                  max={120}
                  value={data.sessionBudget}
                  onChange={(e) => setData({ ...data, sessionBudget: Number(e.target.value) })}
                />
              </div>
              <div className="field">
                <label>{copy.maxSlowRatio}</label>
                <input
                  id="set-max-slow"
                  type="number"
                  min={0}
                  max={1}
                  step={0.05}
                  value={data.maxSlowRatio}
                  onChange={(e) => setData({ ...data, maxSlowRatio: Number(e.target.value) })}
                />
              </div>
              <div className="field">
                <label>{copy.studentLevel}</label>
                <select
                  id="set-student-level"
                  value={data.studentLevel}
                  onChange={(e) => setData({ ...data, studentLevel: e.target.value })}
                >
                  <option value="">{copy.studentLevelAuto}</option>
                  {(data.activeLang === 'ja'
                    ? ['N5', 'N4', 'N3', 'N2', 'N1']
                    : data.activeLang === 'zh'
                      ? ['HSK1', 'HSK2', 'HSK3', 'HSK4', 'HSK5', 'HSK6']
                      : ['beginner', 'intermediate', 'advanced']
                  ).map((lv) => (
                    <option key={lv} value={lv}>
                      {lv}
                    </option>
                  ))}
                </select>
              </div>
              <div className="field">
                <label>{copy.minAccuracy}</label>
                <input
                  id="set-min-accuracy"
                  type="number"
                  min={0}
                  max={1}
                  step={0.05}
                  value={data.minAccuracy}
                  onChange={(e) => setData({ ...data, minAccuracy: Number(e.target.value) })}
                />
              </div>
              <div className="field">
                <label>{copy.autoExpand}</label>
                <select
                  id="set-auto-expand"
                  value={data.autoExpand ? 'on' : 'off'}
                  onChange={(e) => setData({ ...data, autoExpand: e.target.value === 'on' })}
                >
                  <option value="on">on</option>
                  <option value="off">off</option>
                </select>
              </div>
            </div>
          </section>

          <section className="card sect">
            <h3>{copy.startup}</h3>
            <div className="field">
              <label htmlFor="set-auto-start">{copy.autoStart}</label>
              <select
                id="set-auto-start"
                value={data.autoStart ? 'on' : 'off'}
                onChange={(e) => setData({ ...data, autoStart: e.target.value === 'on' })}
              >
                <option value="on">on</option>
                <option value="off">off</option>
              </select>
              <div className="hintline">{copy.autoStartHint}</div>
            </div>
          </section>

          <section className="card sect">
            <h3>{copy.ui}</h3>
            <div className="grid2">
              <div className="field">
                <label>{copy.interfaceLang}</label>
                <select
                  id="set-interface-lang"
                  value={data.interfaceLang}
                  onChange={(e) => setData({ ...data, interfaceLang: e.target.value })}
                >
                  {(['zh', 'en', 'ja'] as Lang[]).map((code) => (
                    <option key={code} value={code}>
                      {langNative[code]}
                    </option>
                  ))}
                </select>
              </div>
              <div className="field">
                <label>{copy.theme}</label>
                <select id="set-theme" value={theme} onChange={(e) => onTheme(e.target.value === 'light' ? 'light' : 'dark')}>
                  <option value="light">{copy.light}</option>
                  <option value="dark">{copy.dark}</option>
                </select>
              </div>
            </div>
          </section>
        </div>

        <div className="col">
          <section className="card sect">
            <h3>{copy.ai}</h3>
            <div className="field">
              <label>{copy.explanationLang}</label>
              <select
                id="set-explanation-lang"
                value={data.explanationLang}
                onChange={(e) => setData({ ...data, explanationLang: e.target.value })}
              >
                <option value="">{copy.explanationFollow}</option>
                <option value="zh-CN">中文</option>
                <option value="en">English</option>
                <option value="ja">日本語</option>
              </select>
              <div className="hintline">{copy.explanationLangHint}</div>
            </div>
            <div className="field">
              <label>{copy.baseUrl}</label>
              <input
                type="text"
                value={data.aiBaseUrl}
                onChange={(e) => setData({ ...data, aiBaseUrl: e.target.value })}
              />
            </div>
            <div className="field">
              <label>{copy.model}</label>
              <input type="text" value={data.aiModel} onChange={(e) => setData({ ...data, aiModel: e.target.value })} />
            </div>
            <div className="field">
              <label>{copy.apiKey}</label>
              <input
                type="password"
                placeholder={data.aiConfigured ? '••••••••' : ''}
                value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
              />
            </div>
            <div className="hintline">{copy.apiKeyHint}</div>
          </section>

          <section className="card sect">
            <h3>{copy.passive}</h3>
            <div className="grid2">
              <div className="field">
                <label>{copy.passiveEnabled}</label>
                <select
                  id="set-passive"
                  value={data.passiveEnabled ? 'on' : 'off'}
                  onChange={(e) => setData({ ...data, passiveEnabled: e.target.value === 'on' })}
                >
                  <option value="on">on</option>
                  <option value="off">off</option>
                </select>
              </div>
              <div className="field">
                <label>{copy.passiveMin}</label>
                <input
                  id="set-passive-min"
                  type="number"
                  min={5}
                  max={240}
                  value={data.passiveMin}
                  onChange={(e) => setData({ ...data, passiveMin: Number(e.target.value) })}
                />
              </div>
              <div className="field">
                <label>{copy.passiveMax}</label>
                <input
                  id="set-passive-max"
                  type="number"
                  min={5}
                  max={480}
                  value={data.passiveMax}
                  onChange={(e) => setData({ ...data, passiveMax: Number(e.target.value) })}
                />
              </div>
            </div>
          </section>

          <section className="card sect">
            <h3>{copy.assignment}</h3>
            <div className="grid2">
              <div className="field">
                <label>{copy.cadenceDays}</label>
                <input
                  id="set-cadence-days"
                  type="number"
                  min={1}
                  max={30}
                  value={data.cadenceDays}
                  onChange={(e) => setData({ ...data, cadenceDays: Number(e.target.value) })}
                />
              </div>
              <div className="field">
                <label>{copy.cadenceCount}</label>
                <input
                  id="set-cadence-count"
                  type="number"
                  min={1}
                  max={10}
                  value={data.cadenceCount}
                  onChange={(e) => setData({ ...data, cadenceCount: Number(e.target.value) })}
                />
              </div>
              <div className="field">
                <label>{copy.maxPerSession}</label>
                <input
                  id="set-max-per-session"
                  type="number"
                  min={1}
                  max={20}
                  value={data.maxPerSession}
                  onChange={(e) => setData({ ...data, maxPerSession: Number(e.target.value) })}
                />
              </div>
              <div className="field">
                <label>{copy.aiRecommend}</label>
                <select
                  id="set-ai-recommend"
                  value={data.aiRecommend ? 'on' : 'off'}
                  onChange={(e) => setData({ ...data, aiRecommend: e.target.value === 'on' })}
                >
                  <option value="on">on</option>
                  <option value="off">off</option>
                </select>
              </div>
            </div>
          </section>

          <section className="card sect">
            <h3>{copy.security}</h3>
            <div className="grid2">
              <div className="field">
                <label>{copy.escapeClicks}</label>
                <input
                  id="set-escape-clicks"
                  type="number"
                  min={1}
                  max={20}
                  value={data.escapeClicks}
                  onChange={(e) => setData({ ...data, escapeClicks: Number(e.target.value) })}
                />
              </div>
              <div className="field">
                <label>{copy.escapePasswords}</label>
                <input
                  id="set-escape-passwords"
                  type="number"
                  min={1}
                  max={20}
                  value={data.escapePasswords}
                  onChange={(e) => setData({ ...data, escapePasswords: Number(e.target.value) })}
                />
              </div>
            </div>
          </section>

          <div className="savebar">
            <button className="btn" onClick={() => void save()} disabled={busy}>
              {copy.save}
            </button>
            {message ? <span className={`msg${failed ? ' err' : ''}`}>{message}</span> : null}
          </div>
        </div>
      </div>

      {switchOpen && data ? (
        <div className="backdrop" onClick={() => !switching && setSwitchOpen(false)}>
          <div className="dialog" onClick={(e) => e.stopPropagation()}>
            <h3>{copy.switchTitle}</h3>
            <p className="hintline">{copy.switchWarn}</p>
            <div className="field">
              <label>{copy.course}</label>
              <select id="switch-language" value={switchLang} onChange={(e) => setSwitchLang(e.target.value)}>
                {data.languages.map((code) => (
                  <option key={code} value={code}>
                    {courseLabel(code, lang)}
                  </option>
                ))}
              </select>
            </div>
            <div className="row">
              <button className="btn ghost" onClick={() => setSwitchOpen(false)} disabled={switching}>
                {copy.switchCancel}
              </button>
              <button
                className="btn"
                id="switch-language-confirm"
                disabled={switching}
                onClick={() => {
                  setSwitching(true)
                  setMessage(copy.switchDone)
                  void initCourseLanguage(switchLang)
                    .then(() => window.location.reload())
                    .catch((e) => {
                      setSwitching(false)
                      setFailed(true)
                      setMessage(copy.failed + (e instanceof Error ? e.message : String(e)))
                    })
                }}
              >
                {copy.switchConfirm}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  )
}