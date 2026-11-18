/**
 * Offline packager: assembles a runnable Windows app folder from the local
 * Electron runtime and the built out/ tree. electron-builder needs to download
 * a runtime zip, which is unreliable here; this uses node_modules/electron.
 *
 * Usage: node scripts/pack-dir.mjs [targetDir]
 * Default target: dist/win-unpacked
 */
import { createPackage } from '@electron/asar'
import { cpSync, existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const target = process.argv[2] ?? join(root, 'dist', 'win-unpacked')
const runtime = join(root, 'node_modules', 'electron', 'dist')
const outDir = join(root, 'out')

if (!existsSync(join(outDir, 'main', 'index.js'))) {
  console.error('pack-dir: out/ is missing — run npm run build first')
  process.exit(1)
}
if (!existsSync(join(runtime, 'electron.exe'))) {
  console.error('pack-dir: node_modules/electron/dist is missing')
  process.exit(1)
}

rmSync(target, { recursive: true, force: true })
mkdirSync(target, { recursive: true })
cpSync(runtime, target, { recursive: true })

// The Electron runtime calls itself electron.exe; the service looks for
// vocablock-desktop.exe next to itself.
renameSync(join(target, 'electron.exe'), join(target, 'vocablock-desktop.exe'))
rmSync(join(target, 'resources', 'default_app.asar'), { force: true })
for (const stale of ['LICENSES.chromium.html']) {
  rmSync(join(target, stale), { force: true })
}

const stage = join(target, '.stage')
mkdirSync(stage, { recursive: true })
cpSync(outDir, join(stage, 'out'), { recursive: true })
const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'))
delete pkg.devDependencies
delete pkg.scripts
delete pkg.build
pkg.main = 'out/main/index.js'
writeFileSync(join(stage, 'package.json'), JSON.stringify(pkg, null, 2))

await createPackage(stage, join(target, 'resources', 'app.asar'))
rmSync(stage, { recursive: true, force: true })

// Content packs live next to the app (content/packs/*), not inside the asar:
// users and third parties install dictionaries by dropping a folder in.
const contentSrc = join(root, '..', 'content')
if (existsSync(contentSrc)) {
  cpSync(contentSrc, join(target, 'content'), { recursive: true })
}

console.log('pack-dir: wrote', target)
