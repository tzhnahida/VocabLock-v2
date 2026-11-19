import { describe, expect, it } from 'vitest'
import { mapSettings } from '../api'

describe('mapSettings', () => {
  it('falls back to product defaults for an empty config', () => {
    const s = mapSettings({}, {})
    expect(s.dailyTarget).toBe(20)
    expect(s.studentLevel).toBe('')
    expect(s.minAccuracy).toBe(0.8)
    expect(s.cadenceDays).toBe(7)
    expect(s.cadenceCount).toBe(3)
    expect(s.maxPerSession).toBe(1)
    expect(s.passiveMax).toBe(45)
    expect(s.languageLocked).toBe(false)
  })

  it('maps explicit values, assignment and AI fields', () => {
    const s = mapSettings(
      {
        active_lang: 'ja',
        interface_lang: 'zh',
        student_level: 'N2',
        daily_target: 12,
        daily_time_target: 30,
        expand_batch_size: 6,
        min_accuracy: 0.9,
        auto_expand_words: true,
        auto_start: true,
        theme: 'vscode-light',
        languages: ['ja', 'en'],
        language_locked: true,
        assignment: { cadence_days: 3, cadence_count: 2, max_per_session: 4, ai_recommend: true }
      },
      { base_url: 'https://api.deepseek.com', model: 'deepseek-chat', configured: true }
    )
    expect(s.activeLang).toBe('ja')
    expect(s.studentLevel).toBe('N2')
    expect(s.dailyTimeTarget).toBe(30)
    expect(s.expandBatch).toBe(6)
    expect(s.minAccuracy).toBe(0.9)
    expect(s.cadenceDays).toBe(3)
    expect(s.aiRecommend).toBe(true)
    expect(s.languages).toEqual(['ja', 'en'])
    expect(s.languageLocked).toBe(true)
    expect(s.aiBaseUrl).toBe('https://api.deepseek.com')
    expect(s.aiConfigured).toBe(true)
  })
})
