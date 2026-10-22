import test from 'node:test'
import assert from 'node:assert/strict'

let themeModule = null

try {
  themeModule = await import('../src/shared/theme.ts')
} catch {
  themeModule = null
}

test('getThemeStatePatch keeps theme sync scoped to theme fields', () => {
  assert.equal(typeof themeModule?.getThemeStatePatch, 'function')
  assert.deepEqual(themeModule?.getThemeStatePatch('auto', 'dark'), {
    theme: 'auto',
    resolvedTheme: 'dark',
  })
  assert.deepEqual(Object.keys(themeModule?.getThemeStatePatch('light', 'dark') || {}).sort(), [
    'resolvedTheme',
    'theme',
  ])
})

test('isThemeMode only accepts supported theme values', () => {
  assert.equal(typeof themeModule?.isThemeMode, 'function')
  assert.equal(themeModule?.isThemeMode('auto'), true)
  assert.equal(themeModule?.isThemeMode('dark'), true)
  assert.equal(themeModule?.isThemeMode('light'), true)
  assert.equal(themeModule?.isThemeMode('midnight'), false)
})
