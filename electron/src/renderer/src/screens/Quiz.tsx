import { useCallback, useEffect, useRef, useState } from 'react'
import { t, dyn, typeName, type Lang } from '../i18n'
import type { Dashboard } from '../api'
import {
  assessPronounce,
  completeSession,
  continueSession,
  disputeAnswer,
  loadStudyCards,
  nextQuestion,
  recordStudyTime,
  startSession,
  submitAnswer,
  type PronounceResult,
  type Question,
  evictTTS,
  loadSessionProgress,
  saveSessionProgress,
  type GrammarCard,
  type StudyCard,
  type SubmitResult
} from '../quizApi'
import { useRecorder } from '../audio/useRecorder'
import { audioObjectUrl, wordAudio } from '../ttsApi'
import { st } from '../strings'

type Props = { dash: Dashboard; lang: Lang; onExit: () => void; onAnswered: () => void }

type Phase = 'starting' | 'intro' | 'study' | 'question' | 'feedback' | 'done' | 'preparing' | 'empty' | 'error'

/** Types the service grades from a recording, not from typed text. */
const AUDIO_TYPES = ['read_word', 'read_sentence', 'dialogue_speak']

function formatClock(seconds: number): string {
  return Math.floor(seconds / 60) + ':' + String(seconds % 60).padStart(2, '0')
}

/** 16-bit PCM WAV: reject silence, not short words. */
function audioHasSpeech(base64: string): boolean {
  try {
    const raw = atob(base64)
    const bytes = new Uint8Array(raw.length)
    for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i)
    let sum = 0
    let n = 0
    for (let i = 44; i + 1 < bytes.length; i += 2) {
      const sample = ((bytes[i] | (bytes[i + 1] << 8)) << 16) >> 16
      sum += sample * sample
      n++
    }
    if (n === 0) return false
    return Math.sqrt(sum / n) > 300
  } catch {
    return true
  }
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
  const [wrong, setWrong] = useState(0)
  const [studyCards, setStudyCards] = useState<StudyCard[]>([])
  const [grammarCards, setGrammarCards] = useState<GrammarCard[]>([])
  const [intro, setIntro] = useState({ words: 0, questions: 0, minutes: 0 })
  const [retryTick, setRetryTick] = useState(0)
  const [revealMeaning, setRevealMeaning] = useState(false)
  const fieldLabels =
    lang === 'zh'
      ? { morphology: '形态', collocation: '搭配', syntax: '句法' }
      : lang === 'ja'
        ? { morphology: '形態', collocation: 'コロケーション', syntax: '構文' }
        : { morphology: 'Morphology', collocation: 'Collocation', syntax: 'Syntax' }
  const introCopy =
    lang === 'zh'
      ? { title: '今日学习', sub: 'SM-2 智能复习 + 精选新词', words: '个新词', questions: '题目', minutes: '预计', start: '开始学习' }
      : lang === 'ja'
        ? { title: '今日の学習', sub: 'SM-2 復習 + 厳選された新語', words: '個の新語', questions: '問題', minutes: '予想', start: '学習開始' }
        : { title: "Today's Study", sub: 'SM-2 smart review + curated new words', words: 'new words', questions: 'Questions', minutes: 'Estimated', start: 'Start Learning' }

  const [studyIdx, setStudyIdx] = useState(0)
  const [studyRead, setStudyRead] = useState(false)
  const [recordingCard, setRecordingCard] = useState<number | null>(null)
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

  const skipStudy = useCallback(() => {
    const total = studyCards.length + grammarCards.length
    void saveSessionProgress(total, true).catch(() => {})
    void loadNext()
  }, [studyCards.length, grammarCards.length, loadNext])

  const nextStudyCard = useCallback(() => {
    const total = studyCards.length + grammarCards.length
    // Grammar cards are read-only study material; only word cards require the
    // read-aloud take first.
    if (studyIdx < studyCards.length && !studyRead) return
    // Sentence audio is disposable: drop it once this card is finished.
    const wordCard = studyCards[studyIdx]
    const grammarCard = grammarCards[studyIdx - studyCards.length]
    if (wordCard?.example) void evictTTS(wordCard.example)
    if (grammarCard?.example) void evictTTS(grammarCard.example)
    if (studyIdx + 1 < total) {
      void saveSessionProgress(studyIdx + 1, false).catch(() => {})
      setStudyIdx(studyIdx + 1)
    } else {
      void saveSessionProgress(total, true).catch(() => {})
      void loadNext()
    }
  }, [studyRead, studyIdx, studyCards.length, grammarCards.length, loadNext])

  // Each study card requires one read-aloud; its duration is credited to the
  // session time budget on the server.
  useEffect(() => {
    setStudyRead(false)
    setRecordingCard(null)
    setPron(null)
    setAssessing(false)
    recorder.reset()
    // eslint-disable-next-line react-hooks/exhaustive-deps -- card change only
  }, [studyIdx])

  // Every completed recording (including a re-record) is scored again. The
  // audio bytes are the identity: a new take produces a new base64 string.
  useEffect(() => {
    const card = studyCards[studyIdx]
    if (phase !== 'study' || !card || recordingCard !== card.id) return
    if (recorder.state !== 'ready' || !recorder.audio) return
    if (!audioHasSpeech(recorder.audio)) {
      setRecordingCard(null)
      setStudyRead(false)
      setAssessing(false)
      setPron({ status: 'error', score: 0, error: 'no_speech' })
      return
    }
    setStudyRead(true)
    setPron(null)
    setAssessing(true)
    void recordStudyTime(Math.max(1, recorder.seconds), card.id).catch(() => {})
    void assessPronounce(recorder.audio, card.id)
      .then((r) => setPron(r))
      .catch(() => setPron({ status: 'error', score: 0 }))
      .finally(() => setAssessing(false))
  }, [phase, studyCards, studyIdx, recordingCard, recorder.state, recorder.seconds, recorder.audio])

  useEffect(() => {
    let cancelled = false
    void (async () => {
      try {
        const started = await startSession(language)
        if (cancelled) return
        if (started.preparing) {
          setPhase('preparing')
          window.setTimeout(() => {
            if (!cancelled) setRetryTick((n) => n + 1)
          }, 1500)
          return
        }
        if (started.daily_completed) return setPhase('done')
        if (started.empty) return setPhase('empty')
        // Study-before-test: show the session's new words before asking.
        try {
          const progress = await loadSessionProgress().catch(() => ({ study_index: 0, study_done: false }))
          if (cancelled) return
          if (progress.study_done) {
            await loadNext()
            return
          }
          const preview = await loadStudyCards(language, 8)
          if (cancelled) return
          if (preview.cards.length > 0 || preview.grammar.length > 0) {
            setStudyCards(preview.cards)
            setGrammarCards(preview.grammar)
            if (progress.study_index >= preview.cards.length + preview.grammar.length) {
              await loadNext()
              return
            }
            setStudyIdx(progress.study_index)
            const questions = (started.new_words ?? 0) + (started.review_words ?? 0) + (started.new_grammar ?? 0) + (started.review_grammar ?? 0)
            setIntro({ words: preview.cards.length, questions: Math.max(questions, preview.cards.length), minutes: Math.max(1, Math.round(Math.max(questions, preview.cards.length) * 0.75)) })
            setPhase('intro')
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
  }, [language, loadNext, retryTick])

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
        if (!res.correct) setWrong((n) => n + 1)
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

  const playStudyAudio = useCallback(async (wordId: number) => {
    const audio = audioRef.current
    if (!audio) return
    setAudioState('loading')
    try {
      const res = await wordAudio(wordId)
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
  }, [])

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
    setRevealMeaning(false)
    // eslint-disable-next-line react-hooks/exhaustive-deps -- only on question change
  }, [question?.id])

  // Correct answers advance on their own; wrong answers wait for the learner.
  useEffect(() => {
    if (phase !== 'feedback' || !result?.correct) return
    const timer = window.setTimeout(() => void loadNext(), 350)
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
          <div className="qfoot" style={{ justifyContent: 'center', gap: 10 }}>
            <button className="btn ghost" onClick={onExit}>
              {t(lang, 'quiz.back')}
            </button>
            <button
              className="btn"
              onClick={() => {
                void continueSession().then(() => loadNext())
              }}
            >
              {copy.keepGoing}
            </button>
          </div>
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
    if (phase === 'intro') {
      return (
        <section className="card qcard introcard">
          <div className="qhead">
            <span className="hint">{intro.words} {introCopy.words}</span>
          </div>
          <h1 className="introtagline">{introCopy.title}</h1>
          <p className="introsub">{introCopy.sub}</p>
          <div className="introcounts">
            <div><b>{intro.words}</b><span>{introCopy.words}</span></div>
            <div><b>{intro.questions}</b><span>{introCopy.questions}</span></div>
            <div><b>~{intro.minutes} min</b><span>{introCopy.minutes}</span></div>
          </div>
          <button className="btn introstart" onClick={() => setPhase('study')}>
            {introCopy.start}
          </button>
        </section>
      )
    }
    if (phase === 'study' && studyCards.length + grammarCards.length > 0) {
      const total = studyCards.length + grammarCards.length
      const card = studyCards[studyIdx]
      const grammar = grammarCards[studyIdx - studyCards.length]
      const last = studyIdx >= total - 1
      if (grammar) {
        return (
          <section className="card qcard studycard">
            <div className="qhead">
              <span className="tag">{typeName('grammar', lang)}</span>
              <span className="hint">{studyIdx + 1} / {total}</span>
            </div>
            <h1 className="studyword grammarword">{grammar.title}</h1>
            {grammar.explanation ? <div className="studymeaning">{grammar.explanation}</div> : null}
            {grammar.example ? <div className="studyexample">{grammar.example}</div> : null}
            <div className="qfoot">
              <button className="skipbtn" onClick={skipStudy}>
                {copy.studySkip}
              </button>
              <button className="btn" onClick={nextStudyCard}>
                {last ? copy.studyStart : copy.studyNext}
              </button>
            </div>
          </section>
        )
      }
      if (!card) return null
      return (
        <section className="card qcard studycard">
          <audio ref={audioRef} preload="auto" />
          <div className="qhead">
            <span className="hint">{studyIdx + 1} / {total}</span>
          </div>
          <div className="studyword">{card.word}</div>
          <div className="studyre">
            <button
              type="button"
              className="play"
              onClick={() => void playStudyAudio(card.id)}
              disabled={audioState === 'loading'}
              title={copy.replayAudio}
            >
              <svg viewBox="0 0 24 24">
                <path d="M6 4l10 8-10 8z" fill="currentColor" />
              </svg>
            </button>
            {card.reading}
          </div>
          <div className="studymeaning">{card.meaning}</div>
          <div className="studymeta">
            {card.pos ? <span className="posbadge">{card.pos}</span> : null}
            {card.level ? <span>{card.level}</span> : null}
            {card.syllables ? <span>{card.syllables}</span> : null}
            {card.register ? <span>{card.register}</span> : null}
            {card.pitch ? <span>{card.pitch}</span> : null}
            {card.forms ? <span>{card.forms}</span> : null}
          </div>
          {card.example ? <div className="studyexample">{card.example}</div> : null}
          {card.morphology ? <div className="studyfield"><b>{fieldLabels.morphology}</b><span>{card.morphology}</span></div> : null}
          {card.collocation ? <div className="studyfield"><b>{fieldLabels.collocation}</b><span>{card.collocation}</span></div> : null}
          {card.syntax ? <div className="studyfield"><b>{fieldLabels.syntax}</b><span>{card.syntax}</span></div> : null}
          <div className="studyread">
            <button
              className="btn ghost"
              disabled={recorder.state === 'requesting'}
              onClick={() => {
                if (recorder.state === 'recording') {
                  recorder.stop()
                } else {
                  setPron(null)
                  setRecordingCard(card.id)
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
            ) : null}
          </div>
          {assessing ? (
            <p className="pronfb">{copy.pronAssessing}</p>
          ) : pron ? (
            pron.status === 'ok' ? (
              <div className={'pronfb ' + (Math.round(pron.score <= 1 ? pron.score * 100 : pron.score) >= 40 ? 'ok' : 'warn')}>
                <div className="pronhead">
                  <b>
                    {Math.round(pron.score <= 1 ? pron.score * 100 : pron.score) >= 40
                      ? copy.pronPass
                      : copy.pronNeedWork}
                  </b>
                  <span>{copy.pronScoreLine(Math.round(pron.score <= 1 ? pron.score * 100 : pron.score), 40)}</span>
                </div>
                {(pron.phonemes ?? []).length > 0 ? (
                  <div className="phonemes">
                    {(pron.phonemes ?? []).map((p, i) => (
                      <span key={i} className={p.score >= 0.4 ? 'p-ok' : 'p-bad'}>
                        {p.phoneme}
                        <em>{Math.round(p.score * 100)}%</em>
                      </span>
                    ))}
                  </div>
                ) : null}
              </div>
            ) : (
              <div className="pronfb">
                <span>
                  {pron.status === 'not_configured'
                    ? copy.pronUnavailable
                    : pron.error === 'no_speech'
                      ? copy.pronNoSpeech
                      : copy.pronError}
                </span>
              </div>
            )
          ) : null}
          <div className="qfoot">
            <button className="skipbtn" onClick={skipStudy}>
              {copy.studySkip}
            </button>
            <button className="btn" onClick={nextStudyCard} disabled={!studyRead} title={!studyRead ? copy.studyNeedRead : undefined}>
              {last ? copy.studyStart : copy.studyNext}
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
              placeholder={copy.answerPlaceholder}
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
              {answer ? (
                <div className="l2">
                  {lang === 'zh' ? `你选择了：${answer}` : lang === 'ja' ? `選んだ答え：${answer}` : `Your answer: ${answer}`}
                </div>
              ) : null}
              {!result.correct && result.expected_answer ? (
                <div className="l2">{dyn[lang].correctAnswer(result.expected_answer)}</div>
              ) : null}
              {question.subject_word ? (
                <div className="fbword">
                  <b>{question.subject_word}</b>
                  {question.subject_reading ? <span> {question.subject_reading}</span> : null}
                  {question.subject_meaning ? (
                    <div>
                      {question.immersive && question.meaning_target && !revealMeaning
                        ? question.meaning_target
                        : question.subject_meaning}
                      {question.immersive && question.meaning_target ? (
                        <button className="link" onClick={() => setRevealMeaning((v) => !v)}>
                          {revealMeaning
                            ? lang === 'zh' ? '显示学习语言' : lang === 'ja' ? '学習言語を表示' : 'Show target language'
                            : lang === 'zh' ? '显示中文' : lang === 'ja' ? '中国語を表示' : 'Show Chinese'}
                        </button>
                      ) : null}
                    </div>
                  ) : null}
                </div>
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

  const dayNo = Math.max(1, dash.streak)
  const roundNo = intro.questions || answered || dash.dailyTarget
  const topLine =
    lang === 'zh'
      ? `学习 · 第 ${dayNo} 天 · 本轮 ${roundNo}/${dash.dailyTarget}`
      : lang === 'ja'
        ? `学習 · ${dayNo}日目 · 今回 ${roundNo}/${dash.dailyTarget}`
        : `Study · day ${dayNo} · round ${roundNo}/${dash.dailyTarget}`

  return (
    <div className="content quizshell">
      <div className="quizmain">
        <div className="topline">
          <span>
            <a className="link" onClick={onExit}>
              {t(lang, 'quiz.back')}
            </a>{' '}
            · <b>{topLine}</b>
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
            <span>{t(lang, 'rail.round')}</span>
            <span>{answered} / {dash.dailyTarget}</span>
          </div>
          <div className="dots">
            {Array.from({ length: Math.max(dash.dailyTarget, answered) }).map((_, i) => (
              <i key={i} className={i < answered ? 'd' : i === answered ? 'c' : ''} />
            ))}
          </div>
          {wrong > 0 ? <div className="note">{copy.wrongCount(wrong)}</div> : null}
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

      </div>

      {(phase as Phase) !== 'study' ? <div className="quizbar">
        <button className="btn quiznext" disabled={phase !== 'feedback'} onClick={() => void loadNext()}>
          <i>{t(lang, 'next')}</i>
        </button>
      </div> : null}
    </div>
  )
}