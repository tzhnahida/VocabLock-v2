import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import Settings from '../screens/Settings'

const mocks = vi.hoisted(() => ({
  saveAppConfig: vi.fn(async () => ({})),
  saveAIConfig: vi.fn(async () => ({})),
  loadSettings: vi.fn(async () => ({
    activeLang: 'ja',
    interfaceLang: 'zh',
    explanationLang: '',
    studentLevel: '',
    dailyTarget: 20,
    dailyTimeTarget: 0,
    expandBatch: 10,
    sm2MaxInterval: 180,
    sessionBudget: 0,
    maxSlowRatio: 0.3,
    passiveEnabled: true,
    passiveMin: 25,
    passiveMax: 45,
    cadenceDays: 7,
    cadenceCount: 3,
    maxPerSession: 1,
    aiRecommend: false,
    escapeClicks: 2,
    escapePasswords: 1,
    minAccuracy: 0.8,
    autoExpand: true,
    autoStart: true,
    theme: 'vs-dark',
    languages: ['ja'],
    languageLocked: true,
    aiBaseUrl: '',
    aiModel: '',
    aiConfigured: false
  }))
}))

vi.mock('../api', () => ({
  loadSettings: mocks.loadSettings,
  saveAppConfig: mocks.saveAppConfig,
  saveAIConfig: mocks.saveAIConfig,
  initCourseLanguage: vi.fn(),
  startPlacement: vi.fn(),
  submitPlacement: vi.fn()
}))

describe('Settings component', () => {
  it('saves the chosen level and shows the locked course hint', async () => {
    render(<Settings lang="zh" theme="dark" onTheme={vi.fn()} onLang={vi.fn()} onSaved={vi.fn()} />)

    await waitFor(() => expect(document.querySelector('#set-student-level')).toBeTruthy())
    expect(screen.getByText(/已锁定/)).toBeTruthy()

    const select = document.querySelector('#set-student-level') as HTMLSelectElement
    await userEvent.selectOptions(select, 'N2')
    await userEvent.click(screen.getByRole('button', { name: '保存' }))

    await waitFor(() => expect(mocks.saveAppConfig).toHaveBeenCalled())
    const saved = mocks.saveAppConfig.mock.calls[0][0] as Record<string, unknown>
    expect(saved.student_level).toBe('N2')
  })
})
