import zhCN from '../renderer/src/locales/zh-CN.json'
import en from '../renderer/src/locales/en.json'
import zhTW from '../renderer/src/locales/zh-TW.json'

export type DesktopLanguage = 'zh-CN' | 'en' | 'zh-TW'
type DesktopTranslationParams = Record<string, string | number>

const desktopLocales = {
  'zh-CN': zhCN,
  en,
  'zh-TW': zhTW,
} satisfies Record<DesktopLanguage, Record<string, string>>

let currentDesktopLanguage: DesktopLanguage = 'zh-CN'

export function normalizeDesktopLanguage(language?: string): DesktopLanguage {
  if (!language) return 'zh-CN'
  if (language.startsWith('zh-TW') || language.startsWith('zh-Hant')) return 'zh-TW'
  if (language.startsWith('zh')) return 'zh-CN'
  if (language.startsWith('en')) return 'en'
  return 'zh-CN'
}

export function setDesktopLanguage(language?: string): DesktopLanguage {
  currentDesktopLanguage = normalizeDesktopLanguage(language)
  return currentDesktopLanguage
}

function interpolateDesktop(template: string, params?: DesktopTranslationParams): string {
  if (!params) return template

  return template.replace(/\{\{(\w+)\}\}/g, (_, token: string) => {
    const value = params[token]
    return value === undefined ? '' : String(value)
  })
}

export function translateDesktop(
  key: string,
  language?: string,
  params?: DesktopTranslationParams
): string {
  const normalized = language ? normalizeDesktopLanguage(language) : currentDesktopLanguage
  const template = desktopLocales[normalized][key] ?? desktopLocales['zh-CN'][key] ?? key
  return interpolateDesktop(template, params)
}
