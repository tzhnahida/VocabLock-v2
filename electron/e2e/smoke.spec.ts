import { test, expect, chromium } from '@playwright/test'
import { spawn, execFileSync, type ChildProcess } from 'node:child_process'
import { createServer } from 'node:net'
import { join } from 'node:path'

// Playwright runs with cwd = electron/.
const root = join(process.cwd(), '..')
const goExe = join(root, 'backend', 'vocablock-e2e.exe')

function freePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const srv = createServer()
    srv.once('error', reject)
    srv.listen(0, '127.0.0.1', () => {
      const addr = srv.address()
      srv.close(() => resolve(typeof addr === 'object' && addr ? addr.port : 0))
    })
  })
}

async function waitForCDP(port: number, timeoutMs = 90_000): Promise<void> {
  const deadline = Date.now() + timeoutMs
  while (Date.now() < deadline) {
    try {
      const res = await fetch(`http://127.0.0.1:${port}/json/version`)
      if (res.ok) return
    } catch {
      // not up yet
    }
    await new Promise((r) => setTimeout(r, 500))
  }
  throw new Error('Electron DevTools endpoint never came up')
}

test.describe('electron smoke (mock backend)', () => {
  let child: ChildProcess | undefined
  let port = 0
  let goLog = ''

  test.beforeAll(async () => {
    port = await freePort()
    child = spawn(goExe, ['--mock'], {
      cwd: join(root, 'backend'),
      env: {
        ...process.env,
        VOCABLOCK_ELECTRON_APP: join(root, 'electron'),
        VOCABLOCK_ELECTRON_DEBUG_PORT: String(port)
      },
      stdio: 'pipe'
    })
    child.stdout?.on('data', (d) => (goLog += d.toString()))
    child.stderr?.on('data', (d) => (goLog += d.toString()))
    try {
      await waitForCDP(port)
    } catch (e) {
      throw new Error(
        `${String(e)} (exit=${child.exitCode})\n--- backend log ---\n${goLog.slice(-3000)}`
      )
    }
  })

  test.afterAll(async () => {
    if (child?.pid) {
      try {
        execFileSync('taskkill', ['/PID', String(child.pid), '/T', '/F'], { stdio: 'ignore' })
      } catch {
        // already gone
      }
    }
  })

  test('home -> quiz -> settings', async () => {
    const browser = await chromium.connectOverCDP(`http://127.0.0.1:${port}`)
    const context = browser.contexts()[0]
    const page = context.pages().find((p) => !p.url().startsWith('devtools://')) ?? context.pages()[0]
    // Fresh mock profiles open the onboarding wizard before the shell.
    if (await page.getByText('开始之前，先认识一下你').count()) {
      await page.getByRole('button', { name: '下一步' }).click()
      await page.getByRole('button', { name: '下一步' }).click()
      await page.locator('#onboard-finish').click()
    }
    await page.waitForSelector('.titlebar', { timeout: 60_000 })

    // A focus lock may be up depending on mock state; unlock it first.
    if (await page.locator('#lock-study').count()) {
      await page.locator('#lock-study').click()
    }

    await page.getByRole('button', { name: /开始学习|继续学习/ }).first().click()
    await expect(page.locator('.s-quiz')).toBeVisible({ timeout: 20_000 })

    await page.locator('.sidebar').getByText('设置', { exact: true }).click()
    await expect(page.locator('#set-student-level')).toBeVisible({ timeout: 20_000 })
    await expect(page.getByText('水平测试', { exact: true })).toBeVisible()

    await browser.close()
  })
})
