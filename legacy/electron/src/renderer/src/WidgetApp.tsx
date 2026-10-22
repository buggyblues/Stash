import { useEffect, useState } from 'react'
import WidgetPanel from './components/Widget/WidgetPanel'

type ThemeMode = 'auto' | 'dark' | 'light'

function getStoredTheme(): ThemeMode {
  try {
    const raw = localStorage.getItem('zpaste-settings')
    if (raw) {
      const parsed = JSON.parse(raw)
      if (parsed.theme) return parsed.theme
    }
  } catch {
    // ignore
  }
  return 'auto'
}

function getStoredAccentColor(): string {
  try {
    const raw = localStorage.getItem('zpaste-settings')
    if (raw) {
      const parsed = JSON.parse(raw)
      if (typeof parsed.accentColor === 'string') return parsed.accentColor
    }
  } catch {
    // ignore
  }
  return '#FF7F43'
}

function resolveTheme(mode: ThemeMode): 'dark' | 'light' {
  if (mode === 'auto') {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  }
  return mode
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

function WidgetApp(): React.JSX.Element {
  const [theme, setTheme] = useState<'dark' | 'light'>(() => resolveTheme(getStoredTheme()))
  const [accentColor, setAccentColor] = useState<string>(() => getStoredAccentColor())

  useEffect(() => {
    // Listen for system theme changes (for auto mode)
    const mql = window.matchMedia('(prefers-color-scheme: dark)')
    const handleSystemChange = (): void => {
      const mode = getStoredTheme()
      if (mode === 'auto') {
        setTheme(mql.matches ? 'dark' : 'light')
      }
    }
    mql.addEventListener('change', handleSystemChange)

    // Listen for storage changes (when user changes theme in settings)
    const handleStorage = (e: StorageEvent): void => {
      if (e.key === 'zpaste-settings') {
        setTheme(resolveTheme(getStoredTheme()))
      }
    }
    window.addEventListener('storage', handleStorage)

    const unsubAccentColor = window.api.onAccentColorChanged((color) => {
      setAccentColor(color)
    })

    // Poll for settings changes from same-origin windows (storage event doesn't fire for same-page writes)
    const interval = setInterval(() => {
      setTheme(resolveTheme(getStoredTheme()))
      setAccentColor(getStoredAccentColor())
    }, 2000)

    return () => {
      mql.removeEventListener('change', handleSystemChange)
      window.removeEventListener('storage', handleStorage)
      unsubAccentColor()
      clearInterval(interval)
    }
  }, [])

  useEffect(() => {
    const root = document.documentElement
    if (theme === 'dark') {
      root.classList.add('dark')
      root.classList.remove('light')
    } else {
      root.classList.add('light')
      root.classList.remove('dark')
    }
  }, [theme])

  useEffect(() => {
    applyAccent(accentColor)
  }, [accentColor])

  return (
    <div className={`w-full h-screen ${theme}`}>
      <WidgetPanel />
    </div>
  )
}

export default WidgetApp
