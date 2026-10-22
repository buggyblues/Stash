import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import zhCN from './locales/zh-CN.json'
import en from './locales/en.json'
import zhTW from './locales/zh-TW.json'

const STORAGE_KEY = 'zpaste-settings'

function getInitialLanguage(): string {
  // 1. Check user preference from localStorage
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) {
      const settings = JSON.parse(raw)
      if (settings.language && settings.language !== 'auto') {
        return settings.language
      }
    }
  } catch {
    // ignore
  }

  // 2. Detect system language via navigator
  const sysLang = navigator.language || 'zh-CN'
  if (sysLang.startsWith('zh-TW') || sysLang.startsWith('zh-Hant')) return 'zh-TW'
  if (sysLang.startsWith('zh')) return 'zh-CN'
  if (sysLang.startsWith('en')) return 'en'

  // 3. Fallback
  return 'zh-CN'
}

i18n.use(initReactI18next).init({
  resources: {
    'zh-CN': { translation: zhCN },
    en: { translation: en },
    'zh-TW': { translation: zhTW }
  },
  lng: getInitialLanguage(),
  fallbackLng: 'zh-CN',
  interpolation: {
    escapeValue: false
  }
})

export default i18n
