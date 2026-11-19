import { describe, expect, it } from 'vitest'
import i18n from '../i18n.json'

const locales = Object.keys(i18n) as (keyof typeof i18n)[]

describe('i18n completeness', () => {
  it('has the same keys in zh, en and ja', () => {
    const base = Object.keys(i18n.zh).sort()
    for (const locale of locales) {
      expect(Object.keys(i18n[locale]).sort(), locale).toEqual(base)
    }
  })

  it('has no empty strings', () => {
    for (const locale of locales) {
      for (const [key, value] of Object.entries(i18n[locale])) {
        expect(value, `${locale}.${key}`).not.toBe('')
      }
    }
  })
})
