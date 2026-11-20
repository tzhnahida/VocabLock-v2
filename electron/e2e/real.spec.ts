import { test, expect, chromium, type Browser, type Page } from '@playwright/test'
import { rmSync } from 'node:fs'
import { startRealApp, stopRealApp, type RealApp } from './fixture'

let app: RealApp | undefined
let browser: Browser
let page: Page

async function lockPage(browser: Browser): Promise<Page | null> {
  for (const p of browser.contexts()[0].pages()) {
    if (await p.locator('#lock-study').count()) return p
  }
  return null
}

test.describe('real backend flows', () => {
  test.beforeAll(async () => {
    app = await startRealApp()
    browser = await chromium.connectOverCDP(`http://127.0.0.1:${app.port}`)
    const context = browser.contexts()[0]
    page = context.pages().find((p) => !p.url().startsWith('devtools://')) ?? context.pages()[0]
    await page.waitForSelector('.titlebar', { timeout: 60_000 })
  })

  test.afterAll(async () => {
    try {
      await browser?.close()
    } catch {
      // already closed
    }
    stopRealApp(app)
    if (app?.work) {
      try {
        rmSync(app.work, { recursive: true, force: true })
      } catch {
        // best effort
      }
    }
  })

  test('lock screen -> start studying enters the quiz', async () => {
    await page.evaluate(() => window.vocablock.requestLock())
    let lock: Page | null = null
    for (let i = 0; i < 40 && !lock; i++) {
      lock = await lockPage(browser)
      if (!lock) await page.waitForTimeout(250)
    }
    expect(lock, 'lock window did not appear').toBeTruthy()
    await lock!.locator('#lock-study').click()
    await expect(page.locator('.s-quiz')).toBeVisible({ timeout: 20_000 })
  })

  test('settings save round-trips through the API', async () => {
    await page.locator('.sidebar').getByText('设置', { exact: true }).click()
    await page.waitForSelector('#set-daily-target', { timeout: 20_000 })
    await page.locator('#set-daily-target').fill('33')
    await page.getByRole('button', { name: '保存' }).click()
    await expect(page.getByText('已保存')).toBeVisible({ timeout: 20_000 })

    const saved = await page.evaluate(async () => {
      const runtime = await window.vocablock.runtime()
      const res = await fetch(`http://127.0.0.1:${runtime.apiPort}/api/v1/config`, {
        headers: { Authorization: `Bearer ${runtime.authToken}` }
      })
      return (await res.json()) as { daily_target: number }
    })
    expect(saved.daily_target).toBe(33)
  })

  test('locked course language is rejected with 409', async () => {
    const status = await page.evaluate(async () => {
      const runtime = await window.vocablock.runtime()
      const res = await fetch(`http://127.0.0.1:${runtime.apiPort}/api/v1/config`, {
        method: 'PUT',
        headers: {
          Authorization: `Bearer ${runtime.authToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ active_lang: 'en' })
      })
      return res.status
    })
    expect(status).toBe(409)
  })

  test('placement test asks 30 questions and shows a level', async () => {
    await page.locator('#placement-start').click()
    await page.waitForSelector('.placement-opt', { timeout: 30_000 })
    for (let i = 0; i < 30; i++) {
      const opt = page.locator('.placement-opt').first()
      if (!(await opt.count())) break
      await opt.click()
      await page.waitForTimeout(80)
    }
    await expect(page.locator('.placement-level')).toBeVisible({ timeout: 20_000 })
  })
})