import { useCallback, useEffect, useRef, useState } from 'react'
import { t, dyn, typeName, type Lang } from '../i18n'
import type { Dashboard } from '../api'
import {
  assessPronounce,
  completeSession,
  disputeAnswer,
  loadStudyCards,
  nextQuestion,
  recordStudyTime,
  startSession,
  submitAnswer,
  type PronounceResult,
  type Question,
  type StudyCard,
  type SubmitResult
} from '../quizApi'
import { useRecorder } from '../audio/useRecorder'
import { audioObjectUrl, wordAudio } from '../ttsApi'
import { st } from '../strings'

type Props = { dash: Dashboard; lang: Lang; onExit: () => void; onAnswered: () => void }

type Phase = 'starting' | 'study' | 'question' | 'feedback' | 'done' | 'preparing' | 'empty' | 'error'

/** Types the service grades from a recording, not from typed text. */
const AUDIO_TYPES = ['read_word', 'read_sentence', 'dialogue_speak']

function formatClock(seconds: number): string {
  return Math.floor(seconds / 60) + ':' + String(seconds % 60).padStart(2, '0')
}

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
  const [studyCards, setStudyCards] = useState<StudyCard[]>([])
  const [studyIdx, setStudyIdx] = useState(0)
  const [studyRead, setStudyRead] = useState(false)
  const [pron, setPron] = useState<PronounceResult | null>(null)
  const [assessing, setAssessing] = useState(false)
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

  const nextStudyCard = useCallback(() => {
    if (!studyRead) return
    if (studyIdx + 1 < studyCards.length) setStudyIdx(studyIdx + 1)
    else void loadNext()
  }, [studyRead, studyIdx, studyCards.length, loadNext])

  // Each study card requires one read-aloud; its duration is credited to the
  // session time budget on the server.
  useEffect(() => {
    setStudyRead(false)
    setPron(null)
    setAssessing(false)
    recorder.reset()
    // eslint-disable-next-line react-hooks/exhaustive-deps -- card change only
  }, [studyIdx])

  useEffect(() => {
    const card = studyCards[studyIdx]
    if (phase !== 'study' || !card || studyRead || recorder.state !== 'ready') return
    setStudyRead(true)
    void recordStudyTime(Math.max(1, recorder.seconds), card.id).catch(() => {})
    setAssessing(true)
    void assessPronounce(recorder.audio, card.id)
      .then((r) => setPron(r))
      .catch(() => setPron({ status: 'error', score: 0 }))
      .finally(() => setAssessing(false))
  }, [phase, studyCards, studyIdx, studyRead, recorder.state, recorder.seconds, recorder.audio])

  useEffect(() => {
    let cancelled = false
    void (async () => {
      try {
        const started = await startSession(language)
        if (cancelled) return
        if (started.preparing) return setPhase('preparing')
        if (started.daily_completed) return setPhase('done')
        if (started.empty) return setPhase('empty')
        // Study-before-test: show the session's new words before asking.
        try {
          const cards = await loadStudyCards(language, 8)
          if (cancelled) return
          if (cards.length > 0) {
            setStudyCards(cards)
            setStudyIdx(0)
            setPhase('study')
            return
          }
        } catch {
          // Preview is optional; fall through to the questions.
        }
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
    // Only listening exists to be heard; auto-playing choice questions made the
    // app speak a word the moment a quiz opened.
    if (question.type !== 'listening') return
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
      if (phase === 'study' && (e.key === ' ' || e.key === 'Enter')) {
        e.preventDefault()
        nextStudyCard()
      }
      if (phase === 'feedback' && e.key === ' ') {
        e.preventDefault()
        void loadNext()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [phase, question, submit, loadNext, nextStudyCard])

  useEffect(() => {
    recorder.reset()
    // eslint-disable-next-line react-hooks/exhaustive-deps -- only on question change
  }, [question?.id])

  // Correct answers advance on their own; wrong answers wait for the learner.
  useEffect(() => {
    if (phase !== 'feedback' || !result?.correct) return
    const timer = window.setTimeout(() => void loadNext(), 900)
    return () => window.clearTimeout(timer)
  }, [phase, result, loadNext])

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
    if (phase === 'study' && studyCards.length > 0) {
      const card = studyCards[studyIdx]
      const last = studyIdx >= studyCards.length - 1
      return (
        <section className="card qcard studycard">
          <div className="qhead">
            <span className="tag">{copy.studyPhase}</span>
            <span className="hint">{studyIdx + 1} / {studyCards.length}</span>
          </div>
          <div className="studyword">{card.word}</div>
          {card.reading ? <div className="studyre">{card.reading}</div> : null}
          <div className="studymeaning">{card.meaning}</div>
          <div className="studyhint">{copy.studyHint}</div>
          <div className="studyread">
            <button
              className="btn ghost"
              disabled={recorder.state === 'requesting'}
              onClick={() => {
                if (recorder.state === 'recording') {
                  recorder.stop()
                } else {
                  setPron(null)
                  void recorder.start()
                }
              }}
            >
              {recorder.state === 'recording'
                ? copy.studyReading(recorder.seconds)
                : studyRead
                  ? copy.studyReadAgain
                  : copy.studyRead}
            </button>
            {recorder.state === 'recording' ? (
              <span className="wave" aria-hidden="true">
                {Array.from({ length: 12 }).map((_, i) => (
                  <i key={i} />
                ))}
              </span>
            ) : null}
            <span className="studytimer">
              {recorder.state === 'recording' || studyRead ? formatClock(recorder.seconds) : ''}
            </span>
            {recorder.error ? (
              <span className="studyneed">{copy.recordFailed(recorder.error)}</span>
            ) : studyRead ? (
              <span className="studyok">{copy.studyReadDone}</span>
            ) : (
              <span className="studyneed">{copy.studyNeedRead}</span>
            )}
          </div>
          {assessing ? (
            <p className="pronfb">{copy.pronAssessing}</p>
          ) : pron ? (
            <div className="pronfb">
              {pron.status === 'ok' ? (
                <>
                  <b>{copy.pronScore(Math.round(pron.score <= 1 ? pron.score * 100 : pron.score))}</b>
                  {(pron.phonemes ?? []).filter((p) => p.score < 0.6).length > 0 ? (
                    <span>
                      {copy.pronWeak(
                        (pron.phonemes ?? [])
                          .filter((p) => p.score < 0.6)
                          .slice(0, 4)
                          .map((p) => p.phoneme + ' ' + Math.round(p.score * 100) + '%')
                          .join(' · ')
                      )}
                    </span>
                  ) : (
                    <span className="pronok">{copy.pronGood}</span>
                  )}
                </>
              ) : (
                <span>{pron.status === 'not_configured' ? copy.pronUnavailable : copy.pronError}</span>
              )}
            </div>
          ) : null}
          <div className="qfoot">
            <button className="link" onClick={() => void loadNext()}>
              {copy.studySkip}
            </button>
            <button className="btn" onClick={nextStudyCard} disabled={!studyRead} title={!studyRead ? copy.studyNeedRead : undefined}>
              {last ? copy.studyStart : copy.studyNext}
              <kbd>Space</kbd>
            </button>
          </div>
        </section>
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
            <button
              type="button"
              className="play"
              onClick={() => void playQuestionAudio(question)}
              disabled={audioState === 'loading'}
              title={copy.replayAudio}
            >
              <svg viewBox="0 0 24 24">
                <path d="M6 4l10 8-10 8z" fill="currentColor" />
              </svg>
            </button>
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
                  onClick={() => {
                    if (phase === 'question') void submit(opt)
                  }}
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
          <div className={`fb ${result.correct ? 'ok' : 'bad'}`}>
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
              {!result.correct &&
              result.source === 'ai' &&
              (result.log_id ?? 0) > 0 &&
              // A clearly wrong answer (zero score) or a one-character stub is
              // not worth a "the judge got it wrong" button — it only invites
              // noise on questions that were plain wrong.
              (result.score ?? 0) > 0 &&
              answer.trim().length >= 2 ? (
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

      </section>
    )
  }

  return (
    <div className="content quizshell">
      <div className="quizmain">
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

      {(phase as Phase) !== 'study' ? <div className="quizbar">
        <span className="quizbarhint">
          {phase === 'study'
            ? copy.shellStudy
            : phase === 'feedback'
              ? result?.correct
                ? copy.shellCorrect
                : copy.shellWrong
              : copy.shellAnswer}
        </span>
        <button className="btn quiznext" disabled={phase !== 'feedback'} onClick={() => void loadNext()}>
          <i>{t(lang, 'next')}</i>
          <kbd>Space</kbd>
        </button>
      </div> : null}
    </div>
  )
}
