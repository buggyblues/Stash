import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'

const repoRoot = process.cwd()

function readText(relativePath) {
  return fs.readFileSync(path.join(repoRoot, relativePath), 'utf8')
}

test('accent color changes are wired across renderer windows', () => {
  const preloadSource = readText('src/preload/index.ts')
  const preloadTypes = readText('src/preload/index.d.ts')
  const mainSource = readText('src/main/index.ts')
  const appSource = readText('src/renderer/src/App.tsx')
  const settingsAppSource = readText('src/renderer/src/SettingsApp.tsx')
  const widgetSource = readText('src/renderer/src/WidgetApp.tsx')
  const settingsStoreSource = readText('src/renderer/src/stores/settingsStore.ts')

  assert.match(preloadSource, /setAccentColor:\s*\(color: string\)\s*=>\s*ipcRenderer\.invoke\('settings:setAccentColor', color\)/)
  assert.match(preloadSource, /onAccentColorChanged:\s*\(callback: \(color: string\) => void\)/)
  assert.match(preloadTypes, /setAccentColor: \(color: string\) => Promise<void>/)
  assert.match(preloadTypes, /onAccentColorChanged: \(callback: \(color: string\) => void\) => \(\) => void/)

  assert.match(mainSource, /ipcMain\.handle\('settings:setAccentColor', async \(_, color: string\) => \{/)
  assert.match(mainSource, /win\.webContents\.send\('settings:accentColorChanged', color\)/)

  assert.match(settingsStoreSource, /syncAccentColor: \(color: AccentColor\) => void/)
  assert.match(appSource, /window\.api\.onAccentColorChanged\(\(color\) => \{/)
  assert.match(appSource, /useSettingsStore\.getState\(\)\.syncAccentColor\(color\)/)
  assert.match(settingsAppSource, /window\.api\.onAccentColorChanged\(\(color\) => \{/)
  assert.match(settingsAppSource, /useSettingsStore\.getState\(\)\.syncAccentColor\(color\)/)
  assert.match(widgetSource, /window\.api\.onAccentColorChanged\(\(color\) => \{/)
})
