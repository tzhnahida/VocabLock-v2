import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import Onboarding from '../screens/Onboarding'

const mocks = vi.hoisted(() => ({
  saveProfile: vi.fn(async (_p: Record<string, unknown>) => ({})),
  applyPreset: vi.fn(async () => ({ applied: {}, skipped: [], available: true })),
  initCourseLanguage: vi.fn(async () => ({}))
}))

vi.mock('../api', () => ({
  loadLanguages: vi.fn(async () => ({ value: ['ja', 'en'] })),
  loadCapabilities: vi.fn(async () => ({
    active_language: 'ja',
    ai: true,
    tts: true,
    dict: true,
    asr: true,
    pronounce: true,
    content: { root: '', packs: [] },
    languages: {
      ja: {
        code: 'ja',
        packs: ['ja-jlpt-open'],
        levels: ['N5', 'N4'],
        placement: true,
        tts: true,
        dict: true,
        asr: true,
        pronounce: true,
        question_types: ['choice']
      },
      en: {
        code: 'en',
        packs: [],
        levels: [],
        placement: false,
        tts: true,
        dict: false,
        asr: true,
        pronounce: false,
        question_types: ['choice']
      }
    }
  })),
  loadPresets: vi.fn(async () => ({
    language: 'ja',
    presets: [
      {
        id: 'conversation',
        name: 'Conversation',
        goal: 'conversation',
        direction: 'conversation',
        minutes: 20,
        daily_target: 10,
        daily_time_target: 20,
        session_time_budget: 20,
        max_slow_type_ratio: 0.3,
        available: true
      }
    ]
  })),
  saveProfile: mocks.saveProfile,
  applyPreset: mocks.applyPreset,
  initCourseLanguage: mocks.initCourseLanguage
}))

describe('Onboarding', () => {
  it('saves a profile and finishes', async () => {
    const onDone = vi.fn()
    render(<Onboarding lang="zh" activeLang="ja" onLang={vi.fn()} onDone={onDone} />)

    await userEvent.click(screen.getByRole('button', { name: '下一步' }))
    await userEvent.click(screen.getByRole('button', { name: '下一步' }))
    await waitFor(() => expect(document.querySelector('#onboard-finish')).toBeTruthy())
    await userEvent.click(screen.getByRole('button', { name: '开始学习' }))

    await waitFor(() => expect(mocks.saveProfile).toHaveBeenCalled())
    const saved = mocks.saveProfile.mock.calls[0][0]
    expect(saved.onboarding_done).toBe(true)
    expect(saved.daily_minutes).toBe(20)
    await waitFor(() => expect(onDone).toHaveBeenCalled())
  })
})
