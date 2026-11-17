import { useEffect, useState } from 'react'
import { dyn, type Lang } from '../i18n'
import { st } from '../strings'
import { listAssignments, submitAssignment, type Assignment, type AssignmentList, type AssignmentResult } from '../studyApi'

type Props = { lang: Lang; language: string }


export default function AssignmentCard({ lang, language }: Props) {
  const copy = st(lang, 'assignment')
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
      .catch((err) => console.error('[assignment] load failed', err))
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
                  void listAssignments(language)
                    .then(setData)
                    .catch((err) => console.error('[assignment] reload failed', err))
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