import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'

const repoRoot = process.cwd()

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(repoRoot, relativePath), 'utf8'))
}

function readText(relativePath) {
  return fs.readFileSync(path.join(repoRoot, relativePath), 'utf8')
}

test('all locale bundles expose the same translation keys', () => {
  const localeFiles = [
    'src/renderer/src/locales/zh-CN.json',
    'src/renderer/src/locales/en.json',
    'src/renderer/src/locales/zh-TW.json',
  ]

  const locales = Object.fromEntries(localeFiles.map((file) => [file, readJson(file)]))
  const canonicalKeys = Object.keys(locales['src/renderer/src/locales/zh-CN.json']).sort()

  for (const [file, locale] of Object.entries(locales)) {
    assert.deepEqual(
      Object.keys(locale).sort(),
      canonicalKeys,
      `${file} should stay in sync with zh-CN.json`
    )
  }
})

test('i18n resources include the audited missing keys', () => {
  const requiredKeys = [
    'preview.toolbar.upper',
    'preview.toolbar.lower',
    'preview.toolbar.title',
    'preview.toolbar.camel',
    'preview.toolbar.snake',
    'preview.toolbar.kebab',
    'preview.toolbar.trim',
    'preview.toolbar.noSpace',
    'preview.json.valid',
    'preview.image.alt',
    'widget.imageFallback',
    'panel.tagBar.scrollLeft',
    'panel.tagBar.scrollRight',
     'panel.item.useCount',
     'menu.edit',
     'menu.view',
      'settings.shortcuts.widgetQuickPastePrefix.alt',
      'settings.shortcuts.widgetQuickPastePrefix.control',
      'settings.shortcuts.widgetQuickPastePrefix.command',
    ]

  for (const file of [
    'src/renderer/src/locales/zh-CN.json',
    'src/renderer/src/locales/en.json',
    'src/renderer/src/locales/zh-TW.json',
  ]) {
    const locale = readJson(file)
    for (const key of requiredKeys) {
      assert.ok(key in locale, `${file} should define ${key}`)
    }
  }
})

test('audited UI hotspots do not keep hardcoded or fallback copy', () => {
  const forbiddenSnippetsByFile = {
    'src/renderer/src/components/Panel/TagBar.tsx': [
      'aria-label="Scroll tags left"',
      'aria-label="Scroll tags right"',
    ],
    'src/renderer/src/components/Panel/ClipboardItem.tsx': [
      '{item.use_count}次',
      '>image<',
    ],
    'src/renderer/src/components/Panel/ClipboardCardList.tsx': [
      '{item.use_count}次',
    ],
    'src/renderer/src/components/Widget/WidgetPanel.tsx': [
      "item.preview || 'Image'",
    ],
    'src/renderer/src/components/Preview/PreviewPanel.tsx': [
      "{ label: 'UPPER'",
      "{ label: 'lower'",
      "{ label: 'Title'",
      "{ label: 'camel'",
      "{ label: 'snake'",
      "{ label: 'kebab'",
      "{ label: 'Trim'",
      "{ label: 'NoSpace'",
    ],
    'src/renderer/src/components/Preview/JsonPreview.tsx': [
      "valid ? '✓ Valid JSON'",
    ],
    'src/renderer/src/components/Preview/ImagePreview.tsx': [
      'alt="Clipboard image"',
    ],
    'src/renderer/src/utils/formatters.ts': [
      'error: (e as Error).message',
    ],
    'src/renderer/src/components/Settings/SettingsPage.tsx': [
      "label: '⌥ Option'",
      "label: '⌃ Control'",
      "label: '⌘ Command'",
    ],
    'src/main/index.ts': [
      "label: 'Edit'",
      "label: 'View'",
    ],
  }

  for (const [file, snippets] of Object.entries(forbiddenSnippetsByFile)) {
    const source = readText(file)
    for (const snippet of snippets) {
      assert.ok(!source.includes(snippet), `${file} should not contain ${snippet}`)
    }
  }
})
