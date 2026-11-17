import { useEffect, useState } from 'react'
import { dyn, type Lang } from '../i18n'
import { listAssignments, submitAssignment, type Assignment, type AssignmentList, type AssignmentResult } from '../studyApi'

type Props = { lang: Lang; language: string }

const COPY = {
  zh: {
    title: '今日作业',
    needAI: '作业由 AI 出题：配置 API Key 后可用',
    noDue: '今天没有到期作业',
    placeholder: '用目标语言写下你的回答…',
    submit: '提交',
    submitting: '批改中…',
    score: (n: number) => `得分 ${Math.round(n * 100)}%`,
    corrected: '批改后',
    close: '知道了'
  },
  en: {
    title: "Today's assignment",
    needAI: 'Assignments are AI-generated — set an API key to enable them',
    noDue: 'Nothing due today',
    placeholder: 'Write your answer in the target language…',
    submit: 'Submit',
    submitting: 'Grading…',
    score: (n: number) => `Score ${Math.round(n * 100)}%`,
    corrected: 'Corrected',
    close: 'Got it'
  },
  ja: {
    title: '今日の課題',
    needAI: '課題は AI 生成です — API キーを設定してください',
    noDue: '今日の課題はありません',
    placeholder: '学習言語で回答を書いてください…',
    submit: '提出',
    submitting: '採点中…',
    score: (n: number) => `スコア ${Math.round(n * 100)}%`,
    corrected: '添削後',
    close: 'OK'
  }
} as const

export default function AssignmentCard({ lang, language }: Props) {
  const copy = COPY[lang]
  const [data, setData] = useState<AssignmentList | null>(null)
  const [answer, setAnswer] = useState('')
  const [busy, setBusy] = useState(false)
  const [result, setResult] = useState<AssignmentResult | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    void listAssignments(language)
      .then((res) => {
        if (!cancelled) setData(res)
      })
      .catch(() => undefined)
    return () => {
      cancelled = true
    }
  }, [language])

  const current: Assignment | undefined = data?.assignments?.[0]

  async function send(): Promise<void> {
    if (!current || busy || answer.trim() === '') return
    setBusy(true)
    setError('')
    try {
      setResult(await submitAssignment(current.id, answer.trim()))
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="card c-assign">
      <div className="rh">
        <span>{copy.title}</span>
        {data?.reason === 'no_due' ? <span className="muted">{copy.noDue}</span> : null}
      </div>

      {data === null ? (
        <div className="note">{dyn[lang].loading}</div>
      ) : data.reason === 'ai_required' ? (
        <div className="note">{copy.needAI}</div>
      ) : current === undefined ? (
        <div className="note">{data.message || copy.noDue}</div>
      ) : (
        <>
          <div className="assign-prompt">{current.prompt}</div>
          {current.context ? <div className="note">{current.context}</div> : null}
          {result ? (
            <div className="assign-result">
              <div className="l1">{copy.score(result.score)}</div>
              <div className="l2">
                {copy.corrected}：{result.corrected}
              </div>
              {result.feedback ? <div className="note">{result.feedback}</div> : null}
              <button
                className="btn ghost"
                onClick={() => {
                  setResult(null)
                  setAnswer('')
                  setData(null)
                  void listAssignments(language).then(setData).catch(() => undefined)
                }}
              >
                {copy.close}
              </button>
            </div>
          ) : (
            <>
              <textarea
                className="assign-input"
                value={answer}
                onChange={(e) => setAnswer(e.target.value)}
                placeholder={copy.placeholder}
                rows={3}
              />
              <button className="btn" disabled={busy || answer.trim() === ''} onClick={() => void send()}>
                {busy ? copy.submitting : copy.submit}
              </button>
            </>
          )}
          {error ? <div className="note err">{error}</div> : null}
        </>
      )}
    </section>
  )
}
