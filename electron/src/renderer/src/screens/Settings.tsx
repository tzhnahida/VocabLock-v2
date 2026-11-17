import { useEffect, useState } from 'react'
import { courseLabel, langNative, normaliseLang, type Lang } from '../i18n'
import { loadSettings, saveAIConfig, saveAppConfig, type Settings as SettingsData } from '../api'

type Props = {
  lang: Lang
  theme: 'light' | 'dark'
  onTheme: (theme: 'light' | 'dark') => void
  onLang: (lang: Lang) => void
  onSaved: () => void
}

const COPY = {
  zh: {
    title: '设置',
    learning: '学习',
    ui: '界面',
    ai: 'AI',
    course: '课程语言',
    dailyTarget: '每日目标题数',
    minAccuracy: '达标准确率',
    autoExpand: '允许 AI 自动扩词',
    interfaceLang: '界面语言',
    theme: '主题',
    light: '浅色',
    dark: '深色',
    baseUrl: '接口地址',
    model: '模型',
    apiKey: 'API Key',
    apiKeyHint: '留空表示不修改；写入后保存于服务端 secrets.yaml',
    configured: '已配置',
    notConfigured: '未配置',
    save: '保存',
    saved: '已保存',
    failed: '保存失败：'
  },
  en: {
    title: 'Settings',
    learning: 'Learning',
    ui: 'Interface',
    ai: 'AI',
    course: 'Course language',
    dailyTarget: 'Daily target (questions)',
    minAccuracy: 'Required accuracy',
    autoExpand: 'Allow AI word expansion',
    interfaceLang: 'Interface language',
    theme: 'Theme',
    light: 'Light',
    dark: 'Dark',
    baseUrl: 'Base URL',
    model: 'Model',
    apiKey: 'API key',
    apiKeyHint: 'Leave empty to keep the current key; stored server-side in secrets.yaml',
    configured: 'configured',
    notConfigured: 'not configured',
    save: 'Save',
    saved: 'Saved',
    failed: 'Save failed: '
  },
  ja: {
    title: '設定',
    learning: '学習',
    ui: 'インターフェース',
    ai: 'AI',
    course: '学習言語',
    dailyTarget: '1日の目標問題数',
    minAccuracy: '必要正答率',
    autoExpand: 'AI による単語追加を許可',
    interfaceLang: '表示言語',
    theme: 'テーマ',
    light: 'ライト',
    dark: 'ダーク',
    baseUrl: 'エンドポイント',
    model: 'モデル',
    apiKey: 'API キー',
    apiKeyHint: '空欄なら変更しません。サーバーの secrets.yaml に保存されます',
    configured: '設定済み',
    notConfigured: '未設定',
    save: '保存',
    saved: '保存しました',
    failed: '保存に失敗：'
  }
} as const

export default function Settings({ lang, theme, onTheme, onLang, onSaved }: Props) {
  const copy = COPY[lang]
  const [data, setData] = useState<SettingsData | null>(null)
  const [apiKey, setApiKey] = useState('')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const [failed, setFailed] = useState(false)

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
        min_accuracy: data.minAccuracy,
        auto_expand_words: data.autoExpand,
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
                <select id="set-course" value={data.activeLang} onChange={(e) => setData({ ...data, activeLang: e.target.value })}>
                  {data.languages.map((code) => (
                    <option key={code} value={code}>
                      {courseLabel(code, lang)}
                    </option>
                  ))}
                </select>
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

          <div className="savebar">
            <button className="btn" onClick={() => void save()} disabled={busy}>
              {copy.save}
            </button>
            {message ? <span className={`msg${failed ? ' err' : ''}`}>{message}</span> : null}
          </div>
        </div>
      </div>
    </div>
  )
}
