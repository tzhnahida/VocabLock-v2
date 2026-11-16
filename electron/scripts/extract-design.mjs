import fs from 'node:fs'
import path from 'node:path'

const root = process.argv[2]
const html = fs.readFileSync(path.join(root, 'docs/design/app.html'), 'utf8')
const cssMatch = html.match(/<style>([\s\S]*?)<\/style>/)
if (!cssMatch) throw new Error('no style block')
const outDir = path.join(root, 'electron/src/renderer/src')
fs.mkdirSync(path.join(outDir, 'styles'), { recursive: true })
fs.writeFileSync(path.join(outDir, 'styles/design.css'), cssMatch[1].trim() + '\n')

const line = html.split('\n').find((l) => l.startsWith('const T = '))
const objLiteral = line.slice('const T = '.length).replace(/;\s*$/, '')
const T = new Function('return ' + objLiteral)()
fs.writeFileSync(path.join(outDir, 'i18n.json'), JSON.stringify(T, null, 2) + '\n')

const keys = Object.keys(T.zh)
const missing = { en: keys.filter((k) => !(k in T.en)), ja: keys.filter((k) => !(k in T.ja)) }
console.log('css bytes:', cssMatch[1].length)
console.log('langs:', Object.keys(T).join(','), 'keys:', keys.length)
console.log('missing:', JSON.stringify(missing))
