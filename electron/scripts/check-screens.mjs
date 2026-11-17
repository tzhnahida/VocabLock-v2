/**
 * Guards the one link between the shell's routing and its stylesheet: every
 * screen in App.tsx needs a `body[data-screen="<screen>"] .s-<screen>` rule,
 * otherwise the section stays display:none and the screen renders blank.
 * A CSS append was silently skipped once and produced exactly that.
 */
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const app = readFileSync(join(root, 'src/renderer/src/App.tsx'), 'utf8')
// design.css is extracted from the prototype and owns home/quiz/library;
// app.css adds the screens the prototype never drew.
const css =
  readFileSync(join(root, 'src/renderer/src/styles/design.css'), 'utf8') +
  readFileSync(join(root, 'src/renderer/src/styles/app.css'), 'utf8')

const screenType = app.match(/export type Screen =([^\n]+)/)
if (!screenType) {
  console.error('check-screens: Screen type not found in App.tsx')
  process.exit(1)
}
const screens = [...screenType[1].matchAll(/'([a-z]+)'/g)].map((m) => m[1])
const missing = screens.filter((name) => {
  if (name === 'home') return false // the prototype styles the home screen itself
  const selector = `body[data-screen="${name}"] .s-${name}`
  return !css.includes(selector)
})

if (missing.length > 0) {
  console.error('check-screens: no display rule for screen(s):', missing.join(', '))
  console.error('Add: body[data-screen="<screen>"] .s-<screen> { display: block; overflow: auto; }')
  process.exit(1)
}
console.log(`check-screens: ${screens.length} screens wired`)
