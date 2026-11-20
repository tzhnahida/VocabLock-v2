import { useState } from 'react'
import { st } from '../strings'
import type { Lang } from '../i18n'
import { summarizeSession } from '../quizApi'

type Props = { lang: Lang; onApplied: () => void }

/** Runs the existing AI session summary + plan generator from the home screen. */
export default function PlanTune({ lang, onApplied }: Props) {
  const copy = st(lang, 'planTune')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')

  async function run(): Promise<void> {
    if (busy) return
    setBusy(true)
    setMessage('')
    try {
      const res = await summarizeSession()
      if (res.message) {
        setMessage(copy.noData)
        return
      }
      const wc = res.plan?.tomorrow?.word_count
      const diff = res.plan?.tomorrow?.difficulty
      if (typeof wc === 'number' && wc > 0) {
        setMessage(copy.done(String(wc), diff ?? '—'))
        onApplied()
      } else if (res.warning) {
        setMessage(copy.failed(res.warning))
      } else {
        setMessage(copy.noChange)
      }
    } catch (e) {
      setMessage(copy.failed(e instanceof Error ? e.message : String(e)))
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="card c-plantune">
      <div className="rh">
        <span>{copy.title}</span>
      </div>
      <p className="hintline">{copy.hint}</p>
      <button className="btn" disabled={busy} onClick={() => void run()}>
        {busy ? copy.busy : copy.run}
      </button>
      {message ? <p className="hintline">{message}</p> : null}
    </section>
  )
}
