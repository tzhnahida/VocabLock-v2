import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import Lock from '../screens/Lock'

const dash = {
  reviewedToday: 0,
  dailyTarget: 20,
  words: [
    { id: 1, word: '泳ぐ', reading: 'およぐ', meaning: '游泳' },
    { id: 2, word: '学校', reading: 'がっこう', meaning: '学校' },
    { id: 3, word: '水', reading: 'みず', meaning: '水' },
    { id: 4, word: '本', reading: 'ほん', meaning: '书' }
  ]
} as any

describe('Lock component', () => {
  it('calls onStudy when the start button is pressed', async () => {
    const onStudy = vi.fn()
    render(<Lock dash={dash} lang="zh" onExit={vi.fn()} onStudy={onStudy} />)
    await userEvent.click(screen.getByRole('button', { name: '开始学习' }))
    expect(onStudy).toHaveBeenCalledTimes(1)
  })

  it('marks the correct option after a pick', async () => {
    render(<Lock dash={dash} lang="zh" onExit={vi.fn()} onStudy={vi.fn()} />)
    await userEvent.click(screen.getByText('游泳'))
    expect(screen.getByText('游泳').closest('.opt')?.textContent).toContain('✓')
  })
})
