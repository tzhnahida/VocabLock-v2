import { describe, expect, it } from 'vitest'
import { buildOptions } from '../screens/Lock'

const words = [
  { id: 1, word: '泳ぐ', reading: 'およぐ', meaning: '游泳' },
  { id: 2, word: '学校', reading: 'がっこう', meaning: '学校' },
  { id: 3, word: '水', reading: 'みず', meaning: '水' },
  { id: 4, word: '本', reading: 'ほん', meaning: '书' },
  { id: 5, word: '猫', reading: 'ねこ', meaning: '' }
] as any

describe('lock self-check options', () => {
  it('uses real meanings and never renders a blank correct option', () => {
    const opts = buildOptions(words, words[0])
    expect(opts.length).toBe(4)
    expect(opts.filter((o) => o.correct)).toHaveLength(1)
    for (const o of opts) expect(o.label.trim()).not.toBe('')
    expect(opts.find((o) => o.correct)?.label).toBe('游泳')
  })

  it('skips empty meanings and duplicate labels', () => {
    const withDupes = [...words, { id: 6, word: '海洋', reading: 'かいよう', meaning: '游泳' }] as any
    const opts = buildOptions(withDupes, words[0])
    expect(new Set(opts.map((o) => o.label)).size).toBe(opts.length)
    expect(opts.some((o) => o.label === '')).toBe(false)
  })
})
