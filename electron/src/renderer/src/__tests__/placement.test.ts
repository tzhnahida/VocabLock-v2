import { describe, expect, it } from 'vitest'
import { bandOrder } from '../screens/Settings'

describe('placement band ordering', () => {
  it('orders N5 -> N1 and HSK1 -> HSK6', () => {
    const jlpt = ['N1', 'N3', 'N5', 'N2', 'N4'].sort((a, b) => bandOrder(a) - bandOrder(b))
    expect(jlpt).toEqual(['N5', 'N4', 'N3', 'N2', 'N1'])
    const hsk = ['HSK5', 'HSK2', 'HSK6', 'HSK1'].sort((a, b) => bandOrder(a) - bandOrder(b))
    expect(hsk).toEqual(['HSK1', 'HSK2', 'HSK5', 'HSK6'])
  })

  it('puts unknown labels last', () => {
    expect(bandOrder('beginner')).toBeGreaterThan(bandOrder('N1'))
  })
})
