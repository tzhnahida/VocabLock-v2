import { useCallback, useEffect, useRef, useState } from 'react'
import { downsample, encodeWav, toBase64 } from './wav'

export type RecorderState = 'idle' | 'requesting' | 'recording' | 'ready' | 'error'

/** 16 kHz mono is what whisper and the pronunciation scorer expect. */
const TARGET_RATE = 16000

export type Recorder = {
  state: RecorderState
  error: string
  seconds: number
  audio: string
  start: () => Promise<void>
  stop: () => void
  reset: () => void
}

export function useRecorder(): Recorder {
  const [state, setState] = useState<RecorderState>('idle')
  const [error, setError] = useState('')
  const [seconds, setSeconds] = useState(0)
  const [audio, setAudio] = useState('')

  const streamRef = useRef<MediaStream | null>(null)
  const ctxRef = useRef<AudioContext | null>(null)
  const nodeRef = useRef<ScriptProcessorNode | null>(null)
  const chunksRef = useRef<Float32Array[]>([])
  const timerRef = useRef<number | null>(null)

  const teardown = useCallback(() => {
    if (timerRef.current !== null) {
      window.clearInterval(timerRef.current)
      timerRef.current = null
    }
    nodeRef.current?.disconnect()
    nodeRef.current = null
    ctxRef.current?.close().catch(() => undefined)
    ctxRef.current = null
    streamRef.current?.getTracks().forEach((track) => track.stop())
    streamRef.current = null
  }, [])

  useEffect(() => teardown, [teardown])

  const start = useCallback(async () => {
    setError('')
    setAudio('')
    setSeconds(0)
    setState('requesting')
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      streamRef.current = stream
      const ctx = new AudioContext()
      ctxRef.current = ctx
      if (ctx.state === 'suspended') await ctx.resume()
      const source = ctx.createMediaStreamSource(stream)
      const node = ctx.createScriptProcessor(4096, 1, 1)
      chunksRef.current = []
      node.onaudioprocess = (event) => {
        chunksRef.current.push(new Float32Array(event.inputBuffer.getChannelData(0)))
      }
      source.connect(node)
      node.connect(ctx.destination)
      nodeRef.current = node
      setState('recording')
      timerRef.current = window.setInterval(() => setSeconds((s) => s + 1), 1000)
    } catch (e) {
      teardown()
      const name = e instanceof Error ? e.name : ''
      setError(name === 'NotAllowedError' || name === 'NotFoundError' ? 'permission' : String(e))
      setState('error')
    }
  }, [teardown])

  const stop = useCallback(() => {
    if (state !== 'recording') return
    const rate = ctxRef.current?.sampleRate ?? 48000
    const chunks = chunksRef.current
    chunksRef.current = []
    teardown()

    const total = chunks.reduce((n, c) => n + c.length, 0)
    if (total === 0) {
      setState('idle')
      return
    }
    const merged = new Float32Array(total)
    let offset = 0
    for (const chunk of chunks) {
      merged.set(chunk, offset)
      offset += chunk.length
    }
    const pcm = downsample(merged, rate, TARGET_RATE)
    setAudio(toBase64(encodeWav(pcm, TARGET_RATE)))
    setState('ready')
  }, [state, teardown])

  const reset = useCallback(() => {
    teardown()
    setAudio('')
    setSeconds(0)
    setError('')
    setState('idle')
  }, [teardown])

  return { state, error, seconds, audio, start, stop, reset }
}
