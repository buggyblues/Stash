import { useMemo, useCallback } from 'react'
import { useTranslation } from 'react-i18next'

interface Props {
  content: string
}

interface ColorInfo {
  hex: string
  rgb: string
  hsl: string
  valid: boolean
}

export default function ColorPreview({ content }: Props): React.JSX.Element {
  const { t } = useTranslation()
  const color = useMemo(() => parseColor(content.trim()), [content])

  const handleCopy = useCallback((value: string) => {
    navigator.clipboard.writeText(value)
  }, [])

  if (!color.valid) {
    return <div className="p-3 text-xs text-muted-foreground">{t('preview.colorParseError')}</div>
  }

  return (
    <div className="flex flex-col items-center gap-4 p-4 select-none">
      <div
        className="w-24 h-24 rounded-2xl border border-black/10 dark:border-white/15 shadow-[0_8px_20px_-4px_rgba(0,0,0,0.18),inset_0_1px_0_rgba(255,255,255,0.4)]"
        style={{ backgroundColor: color.hex }}
      />
      <div className="space-y-1.5 w-full max-w-xs">
        {[
          { label: 'HEX', value: color.hex },
          { label: 'RGB', value: color.rgb },
          { label: 'HSL', value: color.hsl }
        ].map(({ label, value }) => (
          <div
            key={label}
            onClick={() => handleCopy(value)}
            className="flex items-center justify-between px-3 py-2 rounded-xl bg-black/[0.03] dark:bg-white/[0.06] border border-border/40 hover:bg-black/[0.06] dark:hover:bg-white/[0.1] cursor-pointer transition-all duration-150 active:scale-[0.98]"
          >
            <span className="text-xs text-muted-foreground font-medium">{label}</span>
            <span className="text-xs text-foreground font-mono font-medium">{value}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

function parseColor(input: string): ColorInfo {
  const fallback: ColorInfo = { hex: '', rgb: '', hsl: '', valid: false }

  // HEX
  const hexMatch = input.match(/^#([0-9a-fA-F]{3,8})$/)
  if (hexMatch) {
    let hex = hexMatch[1]
    if (hex.length === 3)
      hex = hex
        .split('')
        .map((c) => c + c)
        .join('')
    if (hex.length === 6 || hex.length === 8) {
      const r = parseInt(hex.slice(0, 2), 16)
      const g = parseInt(hex.slice(2, 4), 16)
      const b = parseInt(hex.slice(4, 6), 16)
      const { h, s, l } = rgbToHsl(r, g, b)
      return {
        hex: `#${hex.slice(0, 6)}`,
        rgb: `rgb(${r}, ${g}, ${b})`,
        hsl: `hsl(${h}, ${s}%, ${l}%)`,
        valid: true
      }
    }
  }

  // RGB/RGBA
  const rgbMatch = input.match(/^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/)
  if (rgbMatch) {
    const r = parseInt(rgbMatch[1])
    const g = parseInt(rgbMatch[2])
    const b = parseInt(rgbMatch[3])
    const { h, s, l } = rgbToHsl(r, g, b)
    return {
      hex: rgbToHex(r, g, b),
      rgb: `rgb(${r}, ${g}, ${b})`,
      hsl: `hsl(${h}, ${s}%, ${l}%)`,
      valid: true
    }
  }

  // HSL/HSLA
  const hslMatch = input.match(/^hsla?\(\s*(\d+)\s*,\s*([\d.]+)%\s*,\s*([\d.]+)%/)
  if (hslMatch) {
    const h = parseInt(hslMatch[1])
    const s = parseFloat(hslMatch[2])
    const l = parseFloat(hslMatch[3])
    const { r, g, b } = hslToRgb(h, s, l)
    return {
      hex: rgbToHex(r, g, b),
      rgb: `rgb(${r}, ${g}, ${b})`,
      hsl: `hsl(${h}, ${s}%, ${l}%)`,
      valid: true
    }
  }

  return fallback
}

function rgbToHex(r: number, g: number, b: number): string {
  return '#' + [r, g, b].map((c) => c.toString(16).padStart(2, '0')).join('')
}

function rgbToHsl(r: number, g: number, b: number): { h: number; s: number; l: number } {
  r /= 255
  g /= 255
  b /= 255
  const max = Math.max(r, g, b),
    min = Math.min(r, g, b)
  const l = (max + min) / 2
  if (max === min) return { h: 0, s: 0, l: Math.round(l * 100) }
  const d = max - min
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
  let h = 0
  if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6
  else if (max === g) h = ((b - r) / d + 2) / 6
  else h = ((r - g) / d + 4) / 6
  return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) }
}

function hslToRgb(h: number, s: number, l: number): { r: number; g: number; b: number } {
  s /= 100
  l /= 100
  const a = s * Math.min(l, 1 - l)
  const f = (n: number) => {
    const k = (n + h / 30) % 12
    return l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1)
  }
  return { r: Math.round(f(0) * 255), g: Math.round(f(8) * 255), b: Math.round(f(4) * 255) }
}
