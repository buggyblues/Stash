export type ContentType = 'url' | 'color' | 'json' | 'base64' | 'code' | 'file_path' | 'text'

interface DetectionResult {
  type: ContentType
  metadata?: Record<string, unknown>
}

const URL_REGEX = /^https?:\/\/[^\s]+$/i
const COLOR_HEX_REGEX = /^#([0-9a-fA-F]{3,8})$/
const COLOR_RGB_REGEX = /^rgba?\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*(,\s*[\d.]+\s*)?\)$/
const COLOR_HSL_REGEX = /^hsla?\(\s*\d+\s*,\s*[\d.]+%\s*,\s*[\d.]+%\s*(,\s*[\d.]+\s*)?\)$/
const BASE64_REGEX = /^[A-Za-z0-9+/=]{20,}$/
const FILE_PATH_REGEX = /^(\/|~\/|\.\/)/

const CODE_INDICATORS = [
  /\bfunction\b/,
  /\bconst\b/,
  /\blet\b/,
  /\bvar\b/,
  /\bimport\b.*\bfrom\b/,
  /\bexport\b/,
  /\bclass\b.*\{/,
  /\bif\s*\(/,
  /\breturn\b/,
  /=>/,
  /\bdef\b/,
  /\bfn\b/,
  /^\s*[{}]\s*$/m
]

const LANGUAGE_PATTERNS: Record<string, RegExp> = {
  typescript: /\b(interface|type|enum|namespace|as\s+\w+|:\s*(string|number|boolean|any))\b/,
  javascript: /\b(function|const|let|var|=>|require\(|module\.exports)\b/,
  python: /\b(def|class|import|from|print\(|self\.|if __name__)\b/,
  rust: /\b(fn|let\s+mut|impl|struct|enum|pub\s+fn|use\s+\w+::)\b/,
  go: /\b(func|package|import|fmt\.|go\s+func)\b/,
  java: /\b(public\s+class|private|protected|static\s+void|System\.out)\b/,
  html: /<\/?[a-z][\s\S]*>/i,
  css: /[{]\s*[\w-]+\s*:\s*[^;]+;\s*[}]/,
  sql: /\b(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|FROM|WHERE)\b/i,
  shell: /^(#!\/|apt|brew|npm|yarn|pip|curl|wget|chmod|mkdir|cd\s)/m
}

export function detectContentType(text: string): DetectionResult {
  const trimmed = text.trim()

  // URL
  if (URL_REGEX.test(trimmed)) {
    return { type: 'url' }
  }

  // Color
  if (
    COLOR_HEX_REGEX.test(trimmed) ||
    COLOR_RGB_REGEX.test(trimmed) ||
    COLOR_HSL_REGEX.test(trimmed)
  ) {
    return { type: 'color', metadata: { value: trimmed } }
  }

  // JSON
  if ((trimmed.startsWith('{') || trimmed.startsWith('[')) && trimmed.length > 2) {
    try {
      JSON.parse(trimmed)
      return { type: 'json' }
    } catch {
      // Not valid JSON, continue
    }
  }

  // Base64
  if (BASE64_REGEX.test(trimmed) && trimmed.length > 30) {
    try {
      const decoded = Buffer.from(trimmed, 'base64')
      if (decoded.length > 0 && decoded.toString('base64') === trimmed) {
        return { type: 'base64' }
      }
    } catch {
      // Not valid base64
    }
  }

  // File path
  if (FILE_PATH_REGEX.test(trimmed) && !trimmed.includes('\n')) {
    return { type: 'file_path' }
  }

  // Code detection
  const codeScore = CODE_INDICATORS.reduce((score, regex) => {
    return score + (regex.test(trimmed) ? 1 : 0)
  }, 0)

  if (codeScore >= 2 || (trimmed.includes(';') && trimmed.includes('{') && trimmed.includes('}'))) {
    const language = detectLanguage(trimmed)
    return { type: 'code', metadata: { language } }
  }

  return { type: 'text' }
}

function detectLanguage(text: string): string {
  for (const [lang, regex] of Object.entries(LANGUAGE_PATTERNS)) {
    if (regex.test(text)) {
      return lang
    }
  }
  return 'plaintext'
}
