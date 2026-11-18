import { useCallback, useEffect, useRef, useState } from 'react'
import { t, dyn, typeName, type Lang } from '../i18n'
import type { Dashboard } from '../api'
import {
  completeSession,
  disputeAnswer,
  nextQuestion,
  startSession,
  submitAnswer,
  type Question,
  type SubmitResult
} from '../quizApi'
import { useRecorder } from '../audio/useRecorder'
import { audioObjectUrl, wordAudio } from '../ttsApi'
import { st } from '../strings'

type Props = { dash: Dashboard; lang: Lang; onExit: () => void; onAnswered: () => void }

type Phase = 'starting' | 'question' | 'feedback' | 'done' | 'preparing' | 'empty' | 'error'

/** Types the service grades from a recording, not from typed text. */
const AUDIO_TYPES = ['read_word', 'read_sentence', 'dialogue_speak']

/**
 * M1 quiz loop against the real service: session/start → next → submit → next.
 * Judging, SM-2 and the review log all happen on the Go side; this screen only
 * renders the branch the server chose (preparing / empty / done / error).
 */
export default function Quiz({ dash, lang, onExit, onAnswered }: Props) {
  const [phase, setPhase] = useState<Phase>('starting')
  const [question, setQuestion] = useState<Question | null>(null)
  const [result, setResult] = useState<SubmitResult | null>(null)
  const [answer, setAnswer] = useState('')
  const [error, setError] = useState('')
  const [answered, setAnswered] = useState(0)
  const [disputed, setDisputed] = useState(false)
  const inputRef = useRef<HTMLInputElement | null>(null)
  const recorder = useRecorder()
  const copy = st(lang, 'quiz')
  const audioRef = useRef<HTMLAudioElement | null>(null)
  const audioUrlRef = useRef<string | null>(null)
  const [audioState, setAudioState] = useState<'idle' | 'loading' | 'playing' | 'unavailable' | 'error'>('idle')

  const language = dash.activeLang

  const loadNext = useCallback(async () => {
    setPhase('starting')
    setResult(null)
    setAnswer('')
    setDisputed(false)
    try {
      const q = await nextQuestion(language)
      if (!q) {
        setPhase('done')
        void completeSession().catch((err) => console.error('[quiz] complete failed', err))
        return
      }
      setQuestion(q)
      setPhase('question')
      if (!q.options?.length) setTimeout(() => inputRef.current?.focus(), 30)
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e))
      setPhase('error')
    }
  }, [language])

  useEffect(() => {
    let cancelled = false
    void (async () => {
      try {
        const started = await startSession(language)
        if (cancelled) return
        if (started.preparing) return setPhase('preparing')
        if (started.daily_completed) return setPhase('done')
        if (started.empty) return setPhase('empty')
        await loadNext()
      } catch (e) {
        if (cancelled) return
        setError(e instanceof Error ? e.message : String(e))
        setPhase('error')
      }
    })()
    return () => {
      cancelled = true
    }
  }, [language, loadNext])

  const submit = useCallback(
    async (value: string, audio?: string) => {
      if (!question || phase !== 'question') return
      const trimmed = value.trim()
      // Read-aloud questions carry their answer in the recording: an empty
      // recording is a deliberate skip, not a no-op.
      if (trimmed === '' && audio === undefined) return
      try {
        const res = await submitAnswer({
          questionId: question.id,
          subjectType: question.subject_type,
          subjectId: question.subject_id,
          questionType: question.type,
          answer: trimmed,
          language,
          audio
        })
        setResult(res)
        setAnswered((n) => n + 1)
        setPhase('feedback')
        onAnswered()
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e))
        setPhase('error')
      }
    },
    [question, phase, language, onAnswered]
  )

  /** Listening questions are answered by ear: fetch the word's TTS and play it. */
  const playQuestionAudio = useCallback(
    async (target: Question | null) => {
      const audio = audioRef.current
      if (!target || !audio || target.subject_type !== 'word') return
      setAudioState('loading')
      try {
        const res = await wordAudio(target.subject_id)
        if (res.status !== 'ok' || !res.url) {
          setAudioState(res.status === 'not_configured' ? 'unavailable' : 'error')
          return
        }
        if (audioUrlRef.current) URL.revokeObjectURL(audioUrlRef.current)
        audioUrlRef.current = await audioObjectUrl(res.url)
        audio.src = audioUrlRef.current
        await audio.play()
        setAudioState('playing')
      } catch {
        setAudioState('error')
      }
    },
    []
  )

  // Auto-play on question change: listening exists only to be heard, and the
  // reference Flutter app also plays choice questions as a study aid.
  useEffect(() => {
    if (!question) return
    if (question.subject_type !== 'word') return
    if (question.type !== 'listening' && question.type !== 'choice') return
    void playQuestionAudio(question)
  }, [question, playQuestionAudio])

  useEffect(() => {
    return () => {
      audioRef.current?.pause()
      if (audioUrlRef.current) URL.revokeObjectURL(audioUrlRef.current)
    }
  }, [])

  useEffect(() => {
    function onKey(e: KeyboardEvent): void {
      if (phase === 'question') {
        const options = question?.options ?? []
        if (options.length > 0 && e.key >= '1' && e.key <= String(options.length)) {
          void submit(options[Number(e.key) - 1])
        }
      }
      if (phase === 'feedback' && e.key === ' ') {
        e.preventDefault()
        void loadNext()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [phase, question, submit, loadNext])

  useEffect(() => {
    recorder.reset()
    // eslint-disable-next-line react-hooks/exhaustive-deps -- only on question change
  }, [question?.id])

  const progress = dash.dailyTarget > 0 ? Math.min(1, dash.reviewedToday / dash.dailyTarget) : 0

  function renderBody() {
    if (phase === 'preparing') {
      return <div className="emptystate">{dyn[lang].preparing}</div>
    }
    if (phase === 'empty') {
      return <div className="emptystate">{dyn[lang].emptyVault}</div>
    }
    if (phase === 'done') {
      return (
        <div className="emptystate">
          <div>{dyn[lang].dailyDone}</div>
          <button className="btn" onClick={onExit}>
            {t(lang, 'quiz.back')}
          </button>
        </div>
      )
    }
    if (phase === 'error') {
      return (
        <div className="emptystate">
          <div>{dyn[lang].loadFailed(error)}</div>
          <button className="btn" onClick={() => void loadNext()}>
            {dyn[lang].retry}
          </button>
        </div>
      )
    }
    if (!question) return <div className="emptystate">{dyn[lang].loading}</div>

    const options = question.options ?? []
    const needsAudio = AUDIO_TYPES.includes(question.type)
    // Any field that is the expected answer must not be printed above the
    // input: listening/spelling/fill answer with the word, pronounce with the
    // reading. Older servers may still send them, so filter here too.
    const hideWord = question.type === 'listening' || question.type === 'spelling' || question.type === 'fill'
    const hideReading = hideWord || question.type === 'pronounce'
    return (
      <section className="card qcard">
        <audio ref={audioRef} preload="auto" />
        <div className="qhead">
          <span className="tag">{typeName(question.type, lang)}</span>
          <span className="hint">{options.length > 0 ? dyn[lang].quizHint : dyn[lang].inputHint}</span>
        </div>
        {question.type === 'listening' ? (
          <div className="listen-prompt">
            <button
              className="playbig sm"
              onClick={() => void playQuestionAudio(question)}
              disabled={audioState === 'loading'}
              title={copy.replayAudio}
            >
              <svg viewBox="0 0 24 24">
                <path d="M6 4l10 8-10 8z" fill="currentColor" />
              </svg>
            </button>
            <div className="note">
              {audioState === 'unavailable'
                ? copy.ttsUnavailable
                : audioState === 'error'
                  ? copy.ttsUnavailable
                  : copy.listenFirst}
            </div>
          </div>
        ) : null}
        {question.subject_word && !hideWord ? <h1 className="word">{question.subject_word}</h1> : null}
        {question.subject_reading && !hideReading ? (
          <div className="phon">
            <span className="play">
              <svg viewBox="0 0 24 24">
                <path d="M6 4l10 8-10 8z" fill="currentColor" />
              </svg>
            </span>
            {question.subject_reading}
          </div>
        ) : null}
        <p className="sentence">{question.prompt}</p>

        {needsAudio ? (
          <div className="recorder">
            <div className={`rec-state st-${recorder.state}`}>
              {recorder.state === 'recording'
                ? copy.recordSeconds(recorder.seconds)
                : recorder.state === 'ready'
                  ? copy.recordReady
                  : recorder.state === 'error'
                    ? recorder.error === 'permission'
                      ? copy.recordPermission
                      : copy.recordFailed(recorder.error)
                    : recorder.state === 'requesting'
                      ? dyn[lang].loading
                      : copy.recordHint}
            </div>
            <div className="rec-actions">
              {recorder.state === 'recording' ? (
                <button className="btn" onClick={recorder.stop}>
                  {copy.recordStop}
                </button>
              ) : recorder.state === 'ready' ? (
                <>
                  <button className="btn" disabled={phase === 'feedback'} onClick={() => void submit('', recorder.audio)}>
                    {copy.recordSubmit}
                  </button>
                  <button className="btn ghost" onClick={recorder.reset}>
                    {copy.recordAgain}
                  </button>
                </>
              ) : (
                <button className="btn" disabled={recorder.state === 'requesting'} onClick={() => void recorder.start()}>
                  {copy.record}
                </button>
              )}
              {question.type === 'read_word' || question.type === 'read_sentence' ? (
                <button className="btn ghost" disabled={phase === 'feedback'} onClick={() => void submit('', '')}>
                  {copy.recordSkip}
                </button>
              ) : null}
            </div>
          </div>
        ) : options.length > 0 ? (
          <div className="opts">
            {options.map((opt, i) => {
              const answered = phase === 'feedback'
              const isCorrect = answered && result?.correct === true && answer === opt
              const isWrongPick = answered && answer === opt && result?.correct === false
              const showRight = answered && result?.correct === false && result.expected_answer === opt
              return (
                <div
                  key={i}
                  className={`opt${isCorrect || showRight ? ' good' : ''}${isWrongPick ? ' bad' : ''}`}
                  onClick={() => void submit(opt)}
                >
                  <span className="k">{i + 1}</span>
                  <span>{opt}</span>
                  {isCorrect || showRight ? <span className="mark">✓</span> : null}
                </div>
              )
            })}
          </div>
        ) : (
          <div className="answerbox">
            <input
              ref={inputRef}
              value={answer}
              disabled={phase === 'feedback'}
              onChange={(e) => setAnswer(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') void submit(answer)
              }}
              placeholder={dyn[lang].inputHint}
            />
            <button className="btn" disabled={phase === 'feedback'} onClick={() => void submit(answer)}>
              {dyn[lang].submit}
            </button>
          </div>
        )}

        {phase === 'feedback' && result ? (
          <div className="fb">
            <span className="ic">{result.correct ? '✓' : '×'}</span>
            <div>
              <div className="l1">
                {result.correct ? dyn[lang].correct : (result.feedback || typeName(question.type, lang))}
                {typeof result.score === 'number' && result.score > 0 ? ` · ${Math.round(result.score * 100)}%` : ''}
                {result.next_review_at ? ` · ${dyn[lang].nextIn(result.next_review_at.slice(0, 10))}` : ''}
              </div>
              {!result.correct && result.expected_answer ? (
                <div className="l2">{dyn[lang].correctAnswer(result.expected_answer)}</div>
              ) : null}
              {!result.correct && result.source === 'ai' && (result.log_id ?? 0) > 0 ? (
                <button
                  className="link"
                  disabled={disputed}
                  onClick={() => {
                    if (!result.log_id) return
                    setDisputed(true)
                    void disputeAnswer(result.log_id).catch((err) => console.error('[quiz] dispute failed', err))
                  }}
                >
                  {disputed ? dyn[lang].disputed : dyn[lang].dispute}
                </button>
              ) : null}
            </div>
          </div>
        ) : null}

        <div className="qfoot">
          <div className="keys">
            <span>
              <kbd>Esc</kbd> <i>{t(lang, 'keys.exit')}</i>
            </span>
            <span>
              <kbd>1</kbd>–<kbd>4</kbd> <i>{t(lang, 'keys.choose')}</i>
            </span>
            <span>
              <kbd>R</kbd> <i>{t(lang, 'keys.replay')}</i>
            </span>
          </div>
          <button className="btn" onClick={() => void loadNext()} disabled={phase !== 'feedback'}>
            <i>{t(lang, 'next')}</i>
            <kbd>Space</kbd>
          </button>
        </div>
      </section>
    )
  }

  return (
    <div className="content">
      <div>
        <div className="topline">
          <span>
            <a className="link" onClick={onExit}>
              {t(lang, 'quiz.back')}
            </a>{' '}
            · <b>{t(lang, 'top.line')}</b>
          </span>
          <span>{`${Math.round(dash.accuracy * 100)}%`}</span>
        </div>
        <div className="progress">
          <i style={{ width: `${progress * 100}%` }} />
        </div>
        {renderBody()}
      </div>

      <div className="rail">
        <section className="card rcard">
          <div className="rh">
            <span>{t(lang, 'rail.today')}</span>
            <span>{t(lang, 'rail.goal')}</span>
          </div>
          <div className="big">
            <b>{dash.reviewedToday}</b>
            <span>{`/ ${dash.dailyTarget}`}</span>
          </div>
          <div className="rbar">
            <i style={{ width: `${progress * 100}%` }} />
          </div>
          {answered > 0 ? <div className="note">{`${t(lang, 'rail.round')} · ${answered}`}</div> : null}
        </section>

        <section className="card rcard">
          <div className="rh">
            <span>{t(lang, 'rail.weak')}</span>
            <span>{t(lang, 'rail.week')}</span>
          </div>
          <div className="weak">
            {Object.entries(dash.typeRates)
              .map(([type, rate]) => ({ type, acc: rate.total > 0 ? rate.correct / rate.total : 0 }))
              .sort((a, b) => a.acc - b.acc)
              .slice(0, 3)
              .map((w) => (
                <div className="wrow" key={w.type}>
                  <div className="wl">
                    <span>{typeName(w.type, lang)}</span>
                    <span>{Math.round(w.acc * 100)}%</span>
                  </div>
                  <div className="wbar">
                    <i style={{ width: `${Math.round(w.acc * 100)}%` }} />
                  </div>
                </div>
              ))}
          </div>
        </section>

        <div className="hintbox">
          <kbd>Ctrl</kbd>+<kbd>K</kbd> <span>{t(lang, 'hint.cmd')}</span> · <kbd>Ctrl</kbd>+<kbd>L</kbd> <span>{t(lang, 'hint.lock')}</span>
        </div>
      </div>
    </div>
  )
}
