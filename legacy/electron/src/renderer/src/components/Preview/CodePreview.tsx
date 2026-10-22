import { useEffect, useState } from 'react'
import { codeToHtml } from 'shiki'

interface Props {
  code: string
  language: string
}

// Module-level cache: key = `${code}|${lang}|${theme}` → html
const htmlCache = new Map<string, string>()
const MAX_CACHE_SIZE = 50

export default function CodePreview({ code, language }: Props): React.JSX.Element {
  const [html, setHtml] = useState<string>('')
  const isDark = document.documentElement.classList.contains('dark')

  useEffect(() => {
    let cancelled = false
    const lang = mapLanguage(language === 'plaintext' ? guessLanguage(code) : language)
    const theme = isDark ? 'vitesse-dark' : 'vitesse-light'
    const cacheKey = `${code}|${lang}|${theme}`

    const cached = htmlCache.get(cacheKey)
    if (cached) {
      setHtml(cached)
      return
    }

    codeToHtml(code, { lang, theme })
      .then((result) => {
        if (!cancelled) {
          if (htmlCache.size >= MAX_CACHE_SIZE) {
            const firstKey = htmlCache.keys().next().value
            if (firstKey) htmlCache.delete(firstKey)
          }
          htmlCache.set(cacheKey, result)
          setHtml(result)
        }
      })
      .catch(() => {
        if (!cancelled) setHtml('')
      })
    return () => {
      cancelled = true
    }
  }, [code, language, isDark])

  if (!html) {
    return (
      <pre className="text-xs text-foreground p-3 overflow-auto whitespace-pre-wrap break-all font-mono">
        {code}
      </pre>
    )
  }

  return (
    <div
      dangerouslySetInnerHTML={{ __html: html }}
      className="text-xs overflow-auto p-3 [&_pre]:!bg-transparent [&_pre]:!m-0 [&_pre]:!p-0 [&_code]:!text-xs"
    />
  )
}

function mapLanguage(lang: string): string {
  const map: Record<string, string> = {
    typescript: 'typescript',
    javascript: 'javascript',
    python: 'python',
    rust: 'rust',
    go: 'go',
    java: 'java',
    html: 'html',
    css: 'css',
    sql: 'sql',
    shell: 'shellscript',
    swift: 'swift',
    kotlin: 'kotlin',
    ruby: 'ruby',
    php: 'php',
    c: 'c',
    cpp: 'cpp',
    csharp: 'csharp',
    yaml: 'yaml',
    toml: 'toml',
    markdown: 'markdown',
    plaintext: 'text'
  }
  return map[lang] || lang
}

const LANG_PATTERNS: [string, RegExp][] = [
  ['html', /<\/?(?:div|span|p|a|img|html|head|body|script|style|link|meta|form|input|button|table|tr|td|th|ul|ol|li|h[1-6])\b[^>]*>/i],
  ['typescript', /\b(?:interface|type|enum|namespace|readonly|as\s+\w+|:\s*(?:string|number|boolean|any|void|never|unknown)(?:\s*[;,\]|)]|\s*$))\b/m],
  ['jsx', /(?:import\s+.*\s+from\s+['"]react['"]|<[A-Z]\w+[\s/>]|className=)/],
  ['python', /(?:^\s*(?:def|class)\s+\w+|^\s*import\s+\w+|^\s*from\s+\w+\s+import|print\s*\(|self\.|if\s+__name__\s*==)/m],
  ['rust', /\b(?:fn\s+\w+|let\s+mut\s+|impl\s+|struct\s+\w+|enum\s+\w+|pub\s+fn|use\s+\w+::|\->\s*\w+|Vec<|Option<|Result<)/],
  ['go', /\b(?:func\s+\w+|package\s+\w+|import\s+\(|fmt\.|go\s+func|:=|chan\s+)/],
  ['java', /\b(?:public\s+(?:class|static|void)|private\s+|protected\s+|System\.out|@Override|@Autowired)/],
  ['swift', /\b(?:func\s+\w+|var\s+\w+\s*:|let\s+\w+\s*:|guard\s+let|import\s+(?:UIKit|SwiftUI|Foundation))/],
  ['kotlin', /\b(?:fun\s+\w+|val\s+\w+|var\s+\w+|data\s+class|companion\s+object|override\s+fun)/],
  ['ruby', /\b(?:def\s+\w+|end$|require\s+['"]|class\s+\w+\s*<|attr_(?:reader|writer|accessor)|puts\s+)/m],
  ['php', /(?:<\?php|\$\w+\s*=|function\s+\w+\s*\(|echo\s+|->|=>\s*)/],
  ['css', /(?:^\s*[.#@]\w[\w-]*\s*\{|:\s*[\w-]+\s*;|@media\s|@keyframes\s)/m],
  ['sql', /\b(?:SELECT|INSERT\s+INTO|UPDATE\s+\w+\s+SET|DELETE\s+FROM|CREATE\s+(?:TABLE|INDEX|VIEW)|ALTER\s+TABLE|DROP\s+TABLE|JOIN\s+\w+\s+ON|WHERE|GROUP\s+BY|ORDER\s+BY)\b/i],
  ['shell', /(?:^#!\s*\/|^\s*(?:if\s+\[|for\s+\w+\s+in|while\s+|case\s+)|(?:apt|brew|npm|yarn|pip|curl|wget|chmod|mkdir|echo)\s+)/m],
  ['yaml', /^[\w-]+\s*:\s*(?:\S|$)/m],
  ['javascript', /\b(?:function\s+\w+|const\s+\w+\s*=|let\s+\w+\s*=|var\s+\w+\s*=|=>\s*[{(]|require\s*\(|module\.exports|console\.log)\b/],
  ['c', /\b(?:#include\s*<|int\s+main\s*\(|printf\s*\(|malloc\s*\(|void\s+\w+\s*\(|sizeof\s*\()\b/],
  ['cpp', /\b(?:#include\s*<|std::|cout\s*<<|cin\s*>>|class\s+\w+\s*\{|template\s*<|namespace\s+\w+|nullptr)\b/],
]

function guessLanguage(code: string): string {
  for (const [lang, pattern] of LANG_PATTERNS) {
    if (pattern.test(code)) {
      return lang
    }
  }
  return 'plaintext'
}
