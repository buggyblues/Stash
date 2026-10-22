import type { TFunction } from 'i18next'

const CONTENT_TYPE_KEYS: Record<string, string> = {
  text: 'panel.filter.text',
  code: 'panel.filter.code',
  url: 'panel.filter.url',
  json: 'panel.filter.json',
  color: 'panel.filter.color',
  image: 'panel.filter.image',
  base64: 'panel.filter.base64',
  file_path: 'panel.filter.filePath',
}

export function getContentTypeLabel(t: TFunction, type: string): string {
  const key = CONTENT_TYPE_KEYS[type]
  return key ? t(key) : type
}
