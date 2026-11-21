import { useEffect, useMemo, useRef, useState } from 'react'
import { dyn, type Lang } from '../i18n'
import { st } from '../strings'
import type { Dashboard } from '../api'
import { audioObjectUrl, evictTTS, textAudio, wordAudio } from '../ttsApi'

type Props = { dash: Dashboard; lang: Lang; onStudy: () => void }

/**
 * Two screens: an index that shows the words with their meanings (the user
 * picks what to drill), and the drill itself, where every answer is hidden —
 * no side list, no word text, no meaning until "show text" is pressed.
 */
export default function Listening({ dash, lang, onStudy }: Props) {
  const copy = st(lang, 'listen')
  const words = useMemo(() => dash.words.filter((w) => w.word), [dash.words])
  const [mode, setMode] = useState<'index' | 'drill'>('index')
  const [index, setIndex] = useState(0)
  const [revealed, setRevealed] = useState(false)
  const [status, setStatus] = useState('')
  const [busy, setBusy] = useState(false)
  const [freeText, setFreeText] = useState('')
  const audioRef = useRef<HTMLAudioElement | null>(null)
  const objectUrlRef = useRef<string | null>(null)

  const current = words[index % Math.max(1, words.length)]

  useEffect(() => {
    return () => {
      audioRef.current?.pause()
      if (objectUrlRef.current) URL.revokeObjectURL(objectUrlRef.current)
    }
  }, [])

  async function play(path: string): Promise<void> {
    if (busy) return
    setBusy(true)
    setStatus(copy.playing)
    try {
      const audio = audioRef.current
      if (!audio) throw new Error('audio element missing')
      if (objectUrlRef.current) URL.revokeObjectURL(objectUrlRef.current)
      objectUrlRef.current = await audioObjectUrl(path)
      audio.src = objectUrlRef.current
      audio.onended = () => setStatus('')
      audio.onerror = () => setStatus(copy.failed + 'audio element')
      await audio.play()
    } catch (e) {
      setStatus(copy.failed + (e instanceof Error ? e.message : String(e)))
    } finally {
      setBusy(false)
    }
  }

  async function playWord(): Promise<void> {
    if (!current) return
    setStatus('')
    try {
      const res = await wordAudio(current.id)
      if (res.status !== 'ok' || !res.url) {
        setStatus(res.status === 'not_configured' ? copy.notConfigured : copy.failed + (res.error ?? res.status))
        return
      }
      await play(res.url)
    } catch (e) {
      setStatus(copy.failed + (e instanceof Error ? e.message : String(e)))
    }
  }

  async function playText(): Promise<void> {
    const text = freeText.trim()
    if (text === '') return
    setStatus('')
    try {
      const res = await textAudio(text)
      if (res.status !== 'ok' || !res.url) {
        setStatus(res.status === 'not_configured' ? copy.notConfigured : copy.failed + (res.error ?? res.status))
        return
      }
      await play(res.url)
      // Sentence audio is one-shot: after it has been heard, drop it.
      void evictTTS(text)
    } catch (e) {
      setStatus(copy.failed + (e instanceof Error ? e.message : String(e)))
    }
  }

  function startDrill(i: number): void {
    setIndex(i)
    setRevealed(false)
    setStatus('')
    setMode('drill')
    // The click is a user gesture, so the first play is allowed to start.
    setTimeout(() => void playWord(), 80)
  }

  function backToIndex(): void {
    audioRef.current?.pause()
    setRevealed(false)
    setStatus('')
    setMode('index')
  }

  if (!current) {
    return (
      <div className="home listening">
        <div className="emptystate">{dyn[lang].emptyVault}</div>
      </div>
    )
  }

  if (mode === 'index') {
    return (
      <div className="home listening">
        <audio ref={audioRef} preload="auto" />
        <div className="topline">
          <span>
            <b className="pagetitle">{copy.title}</b> <span className="muted">{copy.indexHint}</span>
          </span>
          <span>
            {copy.provider} · {dash.online ? dyn[lang].online : dyn[lang].offline}{' '}
            <button className="btn" id="listen-to-quiz" onClick={onStudy}>
              {copy.toQuiz}
            </button>
          </span>
        </div>

        <div className="hgrid">
          <div className="col">
            <section className="card">
              <div className="rh">
                <span>{copy.indexTitle}</span>
                <span>{words.length}</span>
              </div>
              <div className="listen-list index">
                {words.map((w, i) => (
                  <div key={w.id} className="listen-row" onClick={() => startDrill(i)}>
                    <span className="w">{w.word}</span>
                    <span className="m">{w.meaning ?? ''}</span>
                  </div>
                ))}
              </div>
            </section>
          </div>

          <div className="col">
            <section className="card">
              <div className="rh">
                <span>{copy.freeText}</span>
              </div>
              <div className="answerbox">
                <input
                  value={freeText}
                  onChange={(e) => setFreeText(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') void playText()
                  }}
                  placeholder={dyn[lang].inputHint}
                />
                <button className="btn" onClick={() => void playText()} disabled={busy || freeText.trim() === ''}>
                  {copy.speak}
                </button>
              </div>
              {status ? <div className="note listen-status">{status}</div> : null}
            </section>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="home listening">
      <audio ref={audioRef} preload="auto" />
      <div className="topline">
        <span>
          <b className="pagetitle">{copy.title}</b> <span className="muted">{copy.drillHint}</span>
        </span>
        <span>
          <button className="btn ghost" id="listen-back" onClick={backToIndex}>
            {copy.back}
          </button>{' '}
          <button className="btn" id="listen-to-quiz" onClick={onStudy}>
            {copy.toQuiz}
          </button>
        </span>
      </div>

      <div className="hgrid">
        <div className="col">
          <section className="card listen-card">
            <div className="qhead">
              <span className="tag">{copy.tag}</span>
              <span className="hint">{`${index + 1} / ${words.length}`}</span>
            </div>

            <button className="playbig" onClick={() => void playWord()} disabled={busy}>
              <svg viewBox="0 0 24 24">
                <path d="M6 4l10 8-10 8z" fill="currentColor" />
              </svg>
            </button>

            <div className="listen-word">
              {revealed ? (
                <>
                  <div className="word">{current.word}</div>
                  <div className="phon">
                    {current.reading ?? ''} {current.pos ? <span className="pos">{current.pos}</span> : null}
                  </div>
                  <div className="note">{current.meaning ?? ''}</div>
                </>
              ) : (
                <div className="listen-hidden">— — —</div>
              )}
            </div>

            <div className="listen-actions">
              <button className="btn ghost" onClick={() => setRevealed(!revealed)}>
                {revealed ? copy.hide : copy.reveal}
              </button>
              <button className="btn ghost" onClick={() => void playWord()} disabled={busy}>
                {copy.replay}
              </button>
              <button
                className="btn"
                onClick={() => {
                  setRevealed(false)
                  setIndex((i) => i + 1)
                }}
              >
                {copy.next}
              </button>
            </div>
            {status ? <div className="note listen-status">{status}</div> : null}
          </section>
        </div>
      </div>
    </div>
  )
}