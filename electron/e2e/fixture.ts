import { spawn, execFileSync, type ChildProcess } from 'node:child_process'
import { cpSync, mkdirSync, mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createServer } from 'node:net'

export function freePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const srv = createServer()
    srv.once('error', reject)
    srv.listen(0, '127.0.0.1', () => {
      const addr = srv.address()
      srv.close(() => resolve(typeof addr === 'object' && addr ? addr.port : 0))
    })
  })
}

export async function waitForCDP(port: number, timeoutMs = 90_000): Promise<void> {
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

export type RealApp = {
  child: ChildProcess
  port: number
  work: string
}

/**
 * Boots the real Go service (not --mock) from a throwaway working directory:
 * minimal configs, local content packs, a fresh SQLite database, and the
 * Electron dev shell via VOCABLOCK_ELECTRON_APP.
 */
export async function startRealApp(): Promise<RealApp> {
  const root = join(process.cwd(), '..')
  const work = mkdtempSync(join(tmpdir(), 'vl-e2e-'))
  cpSync(join(root, 'backend', 'vocablock-e2e.exe'), join(work, 'vocablock.exe'))

  const configs = join(work, 'configs')
  mkdirSync(configs, { recursive: true })
  for (const name of ['tts.yaml', 'dict.yaml', 'asr.yaml', 'pronounce.yaml', 'convo.yaml']) {
    try {
      cpSync(join(root, 'backend', 'configs', name), join(configs, name))
    } catch {
      // optional config file
    }
  }
  for (const dir of ['languages', '_languages', 'prompts']) {
    cpSync(join(root, 'backend', 'configs', dir), join(configs, dir), { recursive: true })
  }
  writeFileSync(
    join(configs, 'app.yaml'),
    [
      'active_lang: ja',
      'interface_lang: zh',
      'daily_target: 20',
      'language_locked: true',
      'auto_start: false',
      'auto_expand_words: false',
      'passive_enabled: false',
      'content_dir: ' + JSON.stringify(join(root, 'content')),
      'ai:',
      '  base_url: ""',
      '  model: ""',
      ''
    ].join('\n')
  )

  const port = await freePort()
  const child = spawn(join(work, 'vocablock.exe'), [], {
    cwd: work,
    env: {
      ...process.env,
      VOCABLOCK_ELECTRON_APP: join(root, 'electron'),
      VOCABLOCK_ELECTRON_DEBUG_PORT: String(port)
    },
    stdio: 'pipe'
  })
  await waitForCDP(port)
  return { child, port, work }
}

export function stopRealApp(app: RealApp | undefined): void {
  if (!app?.child.pid) return
  try {
    execFileSync('taskkill', ['/PID', String(app.child.pid), '/T', '/F'], { stdio: 'ignore' })
  } catch {
    // already gone
  }
}