import { useRef, useState } from 'react'
import { dyn, type Lang } from '../i18n'
import { sendChat, type ChatMessage } from '../aiApi'

type Props = { lang: Lang; online: boolean }

const COPY = {
  zh: {
    title: 'AI 对话',
    hint: '用当前课程语言练习对话',
    placeholder: '说点什么…',
    send: '发送',
    thinking: '思考中…',
    me: '我',
    ai: 'AI',
    needKey: 'AI 未配置：在设置里填 API Key 后重试',
    failed: '发送失败：',
    empty: '还没有对话。试着问一个语法问题，或者让它解释一个词。'
  },
  en: {
    title: 'AI chat',
    hint: 'Practise in the active course language',
    placeholder: 'Say something…',
    send: 'Send',
    thinking: 'Thinking…',
    me: 'You',
    ai: 'AI',
    needKey: 'AI is not configured — set an API key in Settings',
    failed: 'Send failed: ',
    empty: 'No messages yet. Ask about grammar, or have it explain a word.'
  },
  ja: {
    title: 'AI チャット',
    hint: '学習中の言語で会話を練習',
    placeholder: 'メッセージを入力…',
    send: '送信',
    thinking: '考え中…',
    me: 'あなた',
    ai: 'AI',
    needKey: 'AI 未設定 — 設定で API キーを入力してください',
    failed: '送信に失敗：',
    empty: 'まだ会話がありません。文法の質問や単語の説明を試してください。'
  }
} as const

export default function Chat({ lang, online }: Props) {
  const copy = COPY[lang]
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [input, setInput] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [model, setModel] = useState('')
  const listRef = useRef<HTMLDivElement | null>(null)

  async function send(): Promise<void> {
    const text = input.trim()
    if (text === '' || busy) return
    const history = [...messages]
    setMessages([...history, { role: 'user', content: text }])
    setInput('')
    setError('')
    setBusy(true)
    try {
      const res = await sendChat(text, history)
      setModel(res.model)
      setMessages([...history, { role: 'user', content: text }, { role: 'assistant', content: res.reply }])
      requestAnimationFrame(() => {
        listRef.current?.scrollTo({ top: listRef.current.scrollHeight })
      })
    } catch (e) {
      setError(copy.failed + (e instanceof Error ? e.message : String(e)))
    } finally {
      setBusy(false)
    }
  }

  const notConfigured = model === 'none'

  return (
    <div className="home chat">
      <div className="topline">
        <span>
          <b className="pagetitle">{copy.title}</b> <span className="muted">{copy.hint}</span>
        </span>
        <span>{model && !notConfigured ? model : online ? dyn[lang].online : dyn[lang].offline}</span>
      </div>

      <section className="card chat-card">
        <div className="chat-list" ref={listRef}>
          {messages.length === 0 ? <div className="emptystate">{copy.empty}</div> : null}
          {messages.map((m, i) => (
            <div key={i} className={`chat-row ${m.role}`}>
              <div className="who">{m.role === 'user' ? copy.me : copy.ai}</div>
              <div className="bubble">{m.content}</div>
            </div>
          ))}
          {busy ? <div className="chat-row assistant"><div className="who">{copy.ai}</div><div className="bubble muted">{copy.thinking}</div></div> : null}
          {notConfigured && !busy ? <div className="chat-note">{copy.needKey}</div> : null}
          {error ? <div className="chat-note err">{error}</div> : null}
        </div>

        <div className="answerbox">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') void send()
            }}
            placeholder={copy.placeholder}
            disabled={busy}
          />
          <button className="btn" disabled={busy || input.trim() === ''} onClick={() => void send()}>
            {copy.send}
          </button>
        </div>
      </section>
    </div>
  )
}
