import { create } from 'zustand'
import i18n from '../i18n'
import { normalizeMaxItems } from '../../../shared/max-items'
import type { LayoutMode } from '../../../shared/layout-mode'
import { getThemeStatePatch, type ResolvedTheme, type ThemeMode, type AccentColor } from '../../../shared/theme'
export type { LayoutMode } from '../../../shared/layout-mode'
export type { ThemeMode, AccentColor } from '../../../shared/theme'
export type LanguageMode = 'auto' | 'zh-CN' | 'en' | 'zh-TW'

export interface Settings {
  theme: ThemeMode
  accentColor: AccentColor
  language: LanguageMode
  launchAtLogin: boolean
  historyRetention: number // days, 0 = forever
  maxItems: number
  iCloudSync: boolean
  hasCompletedOnboarding: boolean
  customShortcut: string
  sequencePasteShortcut: string
  batchPasteShortcut: string
  addToQueueShortcut: string
  batchPasteSeparator: string
  toggleFilterShortcut: string
  togglePreviewShortcut: string
  openTagShortcut: string
  openSettingsShortcut: string
  cycleLayoutShortcut: string
  widgetFollowFilter: boolean
  widgetToggleShortcut: string
  widgetQuickPastePrefix: string
  layoutMode: LayoutMode
}

interface SettingsState extends Settings {
  resolvedTheme: ResolvedTheme
  setTheme: (theme: ThemeMode) => void
  syncTheme: (theme: ThemeMode) => void
  setAccentColor: (color: AccentColor) => void
  syncAccentColor: (color: AccentColor) => void
  setLanguage: (lang: LanguageMode) => void
  setLaunchAtLogin: (value: boolean) => void
  setHistoryRetention: (days: number) => void
  setMaxItems: (count: number) => void
  setICloudSync: (value: boolean) => void
  setHasCompletedOnboarding: (value: boolean) => void
  setCustomShortcut: (shortcut: string) => void
  setSequencePasteShortcut: (shortcut: string) => void
  setBatchPasteShortcut: (shortcut: string) => void
  setAddToQueueShortcut: (shortcut: string) => void
  setBatchPasteSeparator: (separator: string) => void
  setToggleFilterShortcut: (shortcut: string) => void
  setTogglePreviewShortcut: (shortcut: string) => void
  setOpenTagShortcut: (shortcut: string) => void
  setOpenSettingsShortcut: (shortcut: string) => void
  setCycleLayoutShortcut: (shortcut: string) => void
  setWidgetFollowFilter: (value: boolean) => void
  setWidgetToggleShortcut: (shortcut: string) => void
  setWidgetQuickPastePrefix: (prefix: string) => void
  setLayoutMode: (mode: LayoutMode) => void
  loadSettings: () => void
  saveSettings: () => void
}

const STORAGE_KEY = 'zpaste-settings'
const LAYOUT_SHORTCUT_LEGACY_DEFAULT = 'Alt+L'
const LAYOUT_SHORTCUT_DEFAULT = 'CommandOrControl+J'

function getSystemTheme(): ResolvedTheme {
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

function getThemePatch(theme: ThemeMode): { theme: ThemeMode; resolvedTheme: ResolvedTheme } {
  return getThemeStatePatch(theme, getSystemTheme())
}

function resolveLanguage(mode: LanguageMode): string {
  if (mode !== 'auto') return mode
  const sysLang = navigator.language || 'zh-CN'
  if (sysLang.startsWith('zh-TW') || sysLang.startsWith('zh-Hant')) return 'zh-TW'
  if (sysLang.startsWith('zh')) return 'zh-CN'
  if (sysLang.startsWith('en')) return 'en'
  return 'zh-CN'
}

function loadFromStorage(): Partial<Settings> {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) return JSON.parse(raw)
  } catch {
    // ignore
  }
  return {}
}

function saveToStorage(settings: Settings): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(settings))
  } catch {
    // ignore
  }
}

function normalizeSettings(settings: Settings): Settings {
  return {
    ...settings,
    maxItems: normalizeMaxItems(settings.maxItems),
    cycleLayoutShortcut:
      settings.cycleLayoutShortcut === LAYOUT_SHORTCUT_LEGACY_DEFAULT
        ? LAYOUT_SHORTCUT_DEFAULT
        : settings.cycleLayoutShortcut,
  }
}

const defaults: Settings = {
  theme: 'auto',
  accentColor: '#FF7F43',
  language: 'auto',
  launchAtLogin: false,
  historyRetention: 30,
  maxItems: 2000,
  iCloudSync: false,
  hasCompletedOnboarding: false,
  customShortcut: 'Shift+CommandOrControl+V',
  sequencePasteShortcut: 'CommandOrControl+;',
  batchPasteShortcut: "CommandOrControl+'",
  addToQueueShortcut: 'Space',
  batchPasteSeparator: '\n',
  toggleFilterShortcut: 'CommandOrControl+F',
  togglePreviewShortcut: 'Alt',
  openTagShortcut: 'T',
  openSettingsShortcut: 'CommandOrControl+,',
  cycleLayoutShortcut: LAYOUT_SHORTCUT_DEFAULT,
  widgetFollowFilter: false,
  widgetToggleShortcut: 'Alt+W',
  widgetQuickPastePrefix: 'Alt',
  layoutMode: 'center'
}

const stored = loadFromStorage()
const initialSettings: Settings = normalizeSettings({ ...defaults, ...stored })
const initialTheme = getThemePatch(initialSettings.theme)

export const useSettingsStore = create<SettingsState>((set, get) => ({
  ...initialSettings,
  resolvedTheme: initialTheme.resolvedTheme,

  setTheme: (theme) => {
    const patch = getThemePatch(theme)
    const state = get()
    if (state.theme === patch.theme && state.resolvedTheme === patch.resolvedTheme) {
      return
    }
    set(patch)
    get().saveSettings()
    applyTheme(patch.resolvedTheme)
    applyAccent(get().accentColor)
    window.api.setTheme?.(theme)
  },

  syncTheme: (theme) => {
    const patch = getThemePatch(theme)
    const state = get()
    if (state.theme === patch.theme && state.resolvedTheme === patch.resolvedTheme) {
      return
    }
    set(patch)
    applyTheme(patch.resolvedTheme)
    applyAccent(get().accentColor)
  },

  setAccentColor: (color) => {
    set({ accentColor: color })
    get().saveSettings()
    applyAccent(color)
    window.api.setAccentColor?.(color)
  },

  syncAccentColor: (color) => {
    const state = get()
    if (state.accentColor === color) {
      return
    }
    set({ accentColor: color })
    applyAccent(color)
  },

  setLanguage: (lang) => {
    set({ language: lang })
    const resolved = resolveLanguage(lang)
    i18n.changeLanguage(resolved)
    window.api.setLanguage?.(resolved)
    get().saveSettings()
  },

  setLaunchAtLogin: (value) => {
    set({ launchAtLogin: value })
    get().saveSettings()
  },

  setHistoryRetention: (days) => {
    set({ historyRetention: days })
    get().saveSettings()
  },

  setMaxItems: (count) => {
    const normalized = normalizeMaxItems(count)
    set({ maxItems: normalized })
    window.api.setMaxItems?.(normalized)
    get().saveSettings()
  },

  setICloudSync: (value) => {
    set({ iCloudSync: value })
    if (value) {
      window.api.syncStart?.()
    } else {
      window.api.syncStop?.()
    }
    get().saveSettings()
  },

  setHasCompletedOnboarding: (value) => {
    set({ hasCompletedOnboarding: value })
    get().saveSettings()
  },

  setCustomShortcut: (shortcut) => {
    set({ customShortcut: shortcut })
    get().saveSettings()
  },

  setSequencePasteShortcut: (shortcut) => {
    set({ sequencePasteShortcut: shortcut })
    get().saveSettings()
  },

  setBatchPasteShortcut: (shortcut) => {
    set({ batchPasteShortcut: shortcut })
    get().saveSettings()
  },

  setAddToQueueShortcut: (shortcut) => {
    set({ addToQueueShortcut: shortcut })
    get().saveSettings()
  },

  setBatchPasteSeparator: (separator) => {
    set({ batchPasteSeparator: separator })
    get().saveSettings()
  },

  setToggleFilterShortcut: (shortcut) => {
    set({ toggleFilterShortcut: shortcut })
    get().saveSettings()
  },

  setTogglePreviewShortcut: (shortcut) => {
    set({ togglePreviewShortcut: shortcut })
    get().saveSettings()
  },

  setOpenTagShortcut: (shortcut) => {
    set({ openTagShortcut: shortcut })
    get().saveSettings()
  },

  setOpenSettingsShortcut: (shortcut) => {
    set({ openSettingsShortcut: shortcut })
    get().saveSettings()
  },

  setCycleLayoutShortcut: (shortcut) => {
    set({ cycleLayoutShortcut: shortcut })
    get().saveSettings()
  },

  setWidgetFollowFilter: (value) => {
    set({ widgetFollowFilter: value })
    get().saveSettings()
  },

  setWidgetToggleShortcut: (shortcut) => {
    set({ widgetToggleShortcut: shortcut })
    get().saveSettings()
  },

  setWidgetQuickPastePrefix: (prefix) => {
    set({ widgetQuickPastePrefix: prefix })
    get().saveSettings()
  },

  setLayoutMode: (mode) => {
    set({ layoutMode: mode })
    window.api.setLayoutMode?.(mode)
    get().saveSettings()
  },

  loadSettings: () => {
    const stored = loadFromStorage()
    const merged = normalizeSettings({ ...defaults, ...stored })
    const themePatch = getThemePatch(merged.theme)
    set({ ...merged, resolvedTheme: themePatch.resolvedTheme })
    applyTheme(themePatch.resolvedTheme)
    applyAccent(merged.accentColor)
    window.api.setMaxItems?.(merged.maxItems)
    if (merged.iCloudSync) {
      window.api.syncStart?.()
    }
  },

  saveSettings: () => {
    const state = get()
    const settings: Settings = {
      theme: state.theme,
      accentColor: state.accentColor,
      language: state.language,
      launchAtLogin: state.launchAtLogin,
      historyRetention: state.historyRetention,
      maxItems: normalizeMaxItems(state.maxItems),
      iCloudSync: state.iCloudSync,
      hasCompletedOnboarding: state.hasCompletedOnboarding,
      customShortcut: state.customShortcut,
      sequencePasteShortcut: state.sequencePasteShortcut,
      batchPasteShortcut: state.batchPasteShortcut,
      addToQueueShortcut: state.addToQueueShortcut,
      batchPasteSeparator: state.batchPasteSeparator,
      toggleFilterShortcut: state.toggleFilterShortcut,
      togglePreviewShortcut: state.togglePreviewShortcut,
      openTagShortcut: state.openTagShortcut,
      openSettingsShortcut: state.openSettingsShortcut,
      cycleLayoutShortcut: state.cycleLayoutShortcut,
      widgetFollowFilter: state.widgetFollowFilter,
      widgetToggleShortcut: state.widgetToggleShortcut,
      widgetQuickPastePrefix: state.widgetQuickPastePrefix,
      layoutMode: state.layoutMode
    }
    saveToStorage(settings)
  }
}))

function applyTheme(theme: 'dark' | 'light'): void {
  const root = document.documentElement
  if (theme === 'dark') {
    root.classList.add('dark')
    root.classList.remove('light')
  } else {
    root.classList.add('light')
    root.classList.remove('dark')
  }
}

function hexToHsl(hex: string): { h: number; s: number; l: number } {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex)
  if (!result) return { h: 21, s: 100, l: 64 }
  const r = parseInt(result[1], 16) / 255
  const g = parseInt(result[2], 16) / 255
  const b = parseInt(result[3], 16) / 255
  const max = Math.max(r, g, b)
  const min = Math.min(r, g, b)
  let h = 0
  let s = 0
  const l = (max + min) / 2
  if (max !== min) {
    const d = max - min
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6
    else if (max === g) h = ((b - r) / d + 2) / 6
    else h = ((r - g) / d + 4) / 6
  }
  return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) }
}

function applyAccent(hex: string): void {
  const { h, s, l } = hexToHsl(hex)
  // Light mode: use original lightness; dark mode: brighten for vivid appearance
  const lightL = l
  const darkL = Math.min(Math.max(l, 50) + 8, 80)
  const lightFg = lightL > 58 ? '0 0% 7%' : '0 0% 100%'
  const darkFg = darkL > 58 ? '0 0% 7%' : '0 0% 100%'

  let style = document.getElementById('zpaste-accent-override') as HTMLStyleElement | null
  if (!style) {
    style = document.createElement('style')
    style.id = 'zpaste-accent-override'
    document.head.appendChild(style)
  }
  style.textContent = `
    :root {
      --primary: ${h} ${s}% ${lightL}% !important;
      --accent: ${h} ${s}% ${lightL}% !important;
      --ring: ${h} ${s}% ${lightL}% !important;
      --primary-foreground: ${lightFg} !important;
      --accent-foreground: ${lightFg} !important;
    }
    .dark {
      --primary: ${h} ${s}% ${darkL}% !important;
      --accent: ${h} ${s}% ${darkL}% !important;
      --ring: ${h} ${s}% ${darkL}% !important;
      --primary-foreground: ${darkFg} !important;
      --accent-foreground: ${darkFg} !important;
    }
  `
}

// Listen for system theme changes
if (typeof window !== 'undefined') {
  const mql = window.matchMedia('(prefers-color-scheme: dark)')
  mql.addEventListener('change', () => {
    const state = useSettingsStore.getState()
    if (state.theme === 'auto') {
      const patch = getThemePatch('auto')
      if (state.resolvedTheme === patch.resolvedTheme) {
        return
      }
      useSettingsStore.setState(patch)
      applyTheme(patch.resolvedTheme)
      applyAccent(state.accentColor)
    }
  })

  // Apply initial theme and accent
  applyTheme(initialTheme.resolvedTheme)
  applyAccent(initialSettings.accentColor)
  window.api.setMaxItems?.(initialSettings.maxItems)
}
