import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    include: ['src/**/*.test.{ts,tsx}'],
    environment: 'jsdom',
    // React Testing Library registers its afterEach auto-cleanup only when
    // the test framework exposes globals.
    globals: true
  }
})
