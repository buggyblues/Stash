# Stash Performance Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 10 performance issues across paste flow, search, rendering, and background polling to reduce paste delay from 1s+ to ~50-80ms and improve overall responsiveness.

**Architecture:** Targeted surgical fixes in 7 files. No architectural rewrites. Each task is independent and can be committed separately.

**Tech Stack:** Electron, TypeScript, React 18, Zustand, Shiki, Fuse.js, better-sqlite3

---

### Task 1: Fix paste flow — remove dynamic imports and use async exec

**Files:**
- Modify: `src/main/index.ts` (lines 1, 71-100, 298-339)
- Modify: `src/main/shortcuts.ts` (lines 1-2, 61-96, 98-126, 128-147)

**Step 1: Add clipboard and child_process to top-level imports in index.ts**

At line 1 of `src/main/index.ts`, change:

```typescript
import { app, BrowserWindow, ipcMain } from 'electron'
```

to:

```typescript
import { app, BrowserWindow, ipcMain, clipboard } from 'electron'
```

Also add at the top of the file (after the existing imports, around line 12):

```typescript
import { exec } from 'child_process'
```

**Step 2: Rewrite `clipboard:pasteItem` handler (lines 71-100)**

Replace the entire handler with:

```typescript
ipcMain.handle('clipboard:pasteItem', async (_, id: string) => {
  const item = repository.getItemById(id)
  if (!item) return

  clipboard.writeText(item.content)
  const previousApp = windowManager.getPreviousAppBundleId()
  windowManager.hide()

  // Defer use count update — not on the critical paste path
  process.nextTick(() => repository.incrementUseCount(id))

  // Reactivate previous app then simulate Cmd+V
  setTimeout(() => {
    if (previousApp) {
      exec(
        `osascript -e 'tell application id "${previousApp}" to activate'`,
        () => {
          setTimeout(() => {
            exec(
              `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
            )
          }, 20)
        }
      )
    } else {
      setTimeout(() => {
        exec(
          `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
        )
      }, 20)
    }
  }, 30)
})
```

Key changes:
- `await import('electron')` removed — `clipboard` comes from top-level import
- `require('child_process')` removed — `exec` comes from top-level import
- `execSync` → `exec` (non-blocking)
- `incrementUseCount` moved to `process.nextTick` (off critical path)
- `setTimeout(100)` → `setTimeout(30)`, inner `setTimeout(50)` → `setTimeout(20)`
- Activate app callback chains directly into paste keystroke (no nested timeout on success path)

**Step 3: Rewrite `widget:pasteItem` handler (lines 298-339)**

Replace the entire handler with:

```typescript
ipcMain.handle('widget:pasteItem', async (_, id: string) => {
  const item = repository.getItemById(id)
  if (!item) return

  clipboard.writeText(item.content)

  // Hide widget if not pinned
  if (!widgetManager.getPinned()) {
    widgetManager.hide()
  }

  // Defer use count update
  process.nextTick(() => repository.incrementUseCount(id))

  // Get frontmost app and simulate paste
  exec(
    `osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true'`,
    (err, stdout) => {
      const previousApp = err ? null : stdout.trim()
      setTimeout(() => {
        if (previousApp) {
          exec(
            `osascript -e 'tell application id "${previousApp}" to activate'`,
            () => {
              setTimeout(() => {
                exec(
                  `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
                )
              }, 20)
            }
          )
        } else {
          setTimeout(() => {
            exec(
              `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
            )
          }, 20)
        }
      }, 30)
    }
  )
})
```

**Step 4: Update shortcuts.ts to use async exec**

At line 2 of `src/main/shortcuts.ts`, change:

```typescript
import { execSync } from 'child_process'
```

to:

```typescript
import { exec, execSync } from 'child_process'
```

In `quickPasteByIndex` (lines 61-96), replace the entire method with:

```typescript
private quickPasteByIndex(index: number): void {
  const items = repository.getItems({ limit: 5 })
  if (index >= items.length) return

  const item = items[index]
  clipboard.writeText(item.content)
  process.nextTick(() => repository.incrementUseCount(item.id))

  // Get frontmost app before paste
  exec(
    `osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true'`,
    (err, stdout) => {
      const previousApp = err ? null : stdout.trim()
      setTimeout(() => {
        if (previousApp) {
          exec(
            `osascript -e 'tell application id "${previousApp}" to activate'`,
            () => {
              setTimeout(() => {
                exec(
                  `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
                )
              }, 20)
            }
          )
        } else {
          exec(
            `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
          )
        }
      }, 30)
    }
  )
}
```

In `registerSequencePaste` (line 116), replace `execSync` with `exec`:

```typescript
setTimeout(() => {
  exec(
    `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
  )
}, 100)
```

In `registerBatchPaste` (line 139), same change:

```typescript
setTimeout(() => {
  exec(
    `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
  )
}, 100)
```

**Step 5: Build and verify**

Run: `cd /Users/ryanbzhou/Developer/vibe-coding/freedom/z-paste && npm run build`

Expected: No TypeScript errors. Build succeeds.

**Step 6: Commit**

```bash
git add src/main/index.ts src/main/shortcuts.ts
git commit -m "perf: optimize paste flow — async exec, remove dynamic imports, reduce delays"
```

---

### Task 2: Add search debounce

**Files:**
- Modify: `src/renderer/src/components/Panel/SearchBar.tsx`

**Step 1: Add debounced search handler**

Replace the full file content of `SearchBar.tsx` with:

```typescript
import { useRef, useEffect, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { useClipboardStore } from '../../stores/clipboardStore'
import { Search, X } from 'lucide-react'
import { Input } from '../ui/input'
import { Button } from '../ui/button'

export default function SearchBar(): React.JSX.Element {
  const { t } = useTranslation()
  const inputRef = useRef<HTMLInputElement>(null)
  const debounceRef = useRef<ReturnType<typeof setTimeout>>()
  const { searchQuery, search, setSearchQuery, isVisible } = useClipboardStore()

  useEffect(() => {
    if (isVisible && inputRef.current) {
      inputRef.current.blur()
    }
  }, [isVisible])

  useEffect(() => {
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current)
    }
  }, [])

  const handleChange = useCallback(
    (value: string) => {
      setSearchQuery(value)
      if (debounceRef.current) clearTimeout(debounceRef.current)
      debounceRef.current = setTimeout(() => {
        search(value)
      }, 300)
    },
    [search, setSearchQuery]
  )

  return (
    <div className="flex-1 relative group">
      <div className="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground group-focus-within:text-primary transition-colors">
        <Search className="w-4 h-4" />
      </div>
      <Input
        ref={inputRef}
        type="text"
        value={searchQuery}
        onChange={(e) => handleChange(e.target.value)}
        placeholder={t('panel.search.placeholder')}
        className="h-9 pl-9 pr-8 bg-muted/50 border-transparent focus-visible:bg-background focus-visible:border-input shadow-none"
      />
      {searchQuery && (
        <Button
          variant="ghost"
          size="icon"
          onClick={() => {
            setSearchQuery('')
            search('')
          }}
          className="absolute right-1 top-1/2 -translate-y-1/2 h-7 w-7 text-muted-foreground hover:text-foreground"
        >
          <X className="w-3 h-3" />
        </Button>
      )}
    </div>
  )
}
```

Key changes:
- `search(e.target.value)` on every keystroke → debounced with 300ms
- `setSearchQuery` updates the input immediately (responsive typing)
- The actual IPC search fires 300ms after the user stops typing
- Clear button immediately triggers search with empty string (no debounce)

**Step 2: Build and verify**

Run: `npm run build`

Expected: No TypeScript errors. Build succeeds.

**Step 3: Commit**

```bash
git add src/renderer/src/components/Panel/SearchBar.tsx
git commit -m "perf: debounce search input by 300ms"
```

---

### Task 3: Cache Fuse.js instance in useSearch

**Files:**
- Modify: `src/renderer/src/hooks/useSearch.ts`

**Step 1: Separate Fuse instance from search execution**

Replace the full file content:

```typescript
import { useMemo } from 'react'
import Fuse from 'fuse.js'
import { ClipboardItem, useClipboardStore } from '../stores/clipboardStore'

const fuseOptions = {
  keys: ['content', 'preview'],
  threshold: 0.3,
  ignoreLocation: true,
  minMatchCharLength: 1
}

export function useSearch(): ClipboardItem[] {
  const { items, searchQuery } = useClipboardStore()

  const fuse = useMemo(() => new Fuse(items, fuseOptions), [items])

  const filteredItems = useMemo(() => {
    if (!searchQuery.trim()) return items
    return fuse.search(searchQuery).map((result) => result.item)
  }, [fuse, items, searchQuery])

  return filteredItems
}
```

Key change: `new Fuse(items, fuseOptions)` is now memoized by `items`. The Fuse instance is only rebuilt when the items array changes, not on every search query change.

**Step 2: Build and verify**

Run: `npm run build`

Expected: No errors.

**Step 3: Commit**

```bash
git add src/renderer/src/hooks/useSearch.ts
git commit -m "perf: memoize Fuse.js instance to avoid recreation on every render"
```

---

### Task 4: Conditional data reload on panel show

**Files:**
- Modify: `src/renderer/src/App.tsx`

**Step 1: Add timestamp tracking to skip unnecessary reloads**

Replace the full file content:

```typescript
import { useEffect, useRef, useState } from 'react'
import PanelWindow from './components/Panel/PanelWindow'
import OnboardingPage from './components/Onboarding/OnboardingPage'
import { useClipboardStore } from './stores/clipboardStore'
import { useSettingsStore } from './stores/settingsStore'

function App(): React.JSX.Element {
  const { loadItems, addItem, setVisible } = useClipboardStore()
  const resolvedTheme = useSettingsStore((s) => s.resolvedTheme)
  const hasCompletedOnboarding = useSettingsStore((s) => s.hasCompletedOnboarding)
  const [showOnboarding, setShowOnboarding] = useState(!hasCompletedOnboarding)
  const hasNewItemRef = useRef(false)

  useEffect(() => {
    loadItems()

    const unsubNewItem = window.api.onNewItem((item) => {
      addItem(item)
      hasNewItemRef.current = true
    })

    const unsubShown = window.api.onPanelShown(() => {
      setVisible(true)
      if (hasNewItemRef.current) {
        loadItems()
        hasNewItemRef.current = false
      }
    })

    const unsubHidden = window.api.onPanelHidden(() => {
      setVisible(false)
    })

    return () => {
      unsubNewItem()
      unsubShown()
      unsubHidden()
    }
  }, [])

  return (
    <div className={`w-full h-screen ${resolvedTheme}`}>
      {showOnboarding ? (
        <OnboardingPage onComplete={() => setShowOnboarding(false)} />
      ) : (
        <PanelWindow />
      )}
    </div>
  )
}

export default App
```

Key change: `onPanelShown` only calls `loadItems()` when new items have been added since the panel was last visible. A ref (`hasNewItemRef`) tracks whether `onNewItem` has fired since the last load. This avoids a full DB round-trip on every panel show.

**Step 2: Build and verify**

Run: `npm run build`

Expected: No errors.

**Step 3: Commit**

```bash
git add src/renderer/src/App.tsx
git commit -m "perf: skip data reload on panel show when no new items"
```

---

### Task 5: Add React.memo to ClipboardItem and fix hover re-renders

**Files:**
- Modify: `src/renderer/src/components/Panel/ClipboardItem.tsx` (lines 69, 157, 331)

**Step 1: Add React.memo import and wrap the component**

At line 1, add `memo` to the import:

```typescript
import { useCallback, useState, useRef, useEffect, useMemo, memo } from 'react'
```

At line 69, change:

```typescript
export default function ClipboardItemRow({
```

to:

```typescript
function ClipboardItemRow({
```

At line 331 (after the closing `}` of ClipboardItemRow), add the memo export:

```typescript
export default memo(ClipboardItemRow)
```

**Step 2: Fix onMouseEnter to not trigger store updates**

At line 157, change:

```typescript
onMouseEnter={() => setSelectedIndex(index)}
```

to:

```typescript
onMouseEnter={(e) => {
  e.stopPropagation()
  setSelectedIndex(index)
}}
```

Note: The `React.memo` wrapping is the main fix here. With `React.memo`, only the item whose `isSelected` prop changed will re-render when `selectedIndex` changes. The `stopPropagation` prevents event bubbling.

**Step 3: Build and verify**

Run: `npm run build`

Expected: No errors.

**Step 4: Commit**

```bash
git add src/renderer/src/components/Panel/ClipboardItem.tsx
git commit -m "perf: wrap ClipboardItem in React.memo to prevent unnecessary re-renders"
```

---

### Task 6: Cache Shiki highlighter as module singleton

**Files:**
- Modify: `src/renderer/src/components/Preview/CodePreview.tsx`

**Step 1: Replace implementation with cached highlighter**

Replace the full file content:

```typescript
import { useEffect, useState, useRef } from 'react'
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
```

Key changes:
- Added module-level `htmlCache` (Map) with LRU-like eviction at 50 entries
- If cache hit, sets html immediately (no async work)
- Cache key combines `code + lang + theme` for correctness
- Shiki's `codeToHtml` already internally caches the highlighter instance, so the main win here is caching the HTML output to avoid re-highlighting the same code

**Step 2: Build and verify**

Run: `npm run build`

Expected: No errors.

**Step 3: Commit**

```bash
git add src/renderer/src/components/Preview/CodePreview.tsx
git commit -m "perf: cache Shiki code highlight results at module level"
```

---

### Task 7: Optimize clipboard monitor — only run osascript on content change

**Files:**
- Modify: `src/main/clipboard/monitor.ts` (lines 70, 118, 129-146)

**Step 1: Refactor getFrontmostApp to only run on content change**

The current code calls `this.getFrontmostApp()` at lines 70 and 118 unconditionally when building the item object. But at those points the clipboard content HAS already changed (because we checked the hash above). The issue is actually in the `checkText` and `checkImage` methods — `getFrontmostApp()` is already only called after hash comparison. Let me verify...

Looking at the code again:
- `checkText()` line 48: `if (hash === this.lastTextHash) return` — returns early if no change
- `checkImage()` line 87: `if (hash === this.lastImageHash) return` — returns early if no change
- `getFrontmostApp()` at lines 70 and 118 only runs after the hash check passes

The actual overhead is: `checkImage()` always calls `image.toPNG()` (line 85) and computes hash (line 86) even when the text clipboard changed but the image didn't. Also `clipboard.readImage()` + `image.isEmpty()` runs every 500ms.

Optimize by using `exec` (async) instead of `execSync` for `getFrontmostApp`, and skip image check when text changed:

Replace `getFrontmostApp` method (lines 129-146) with an async version:

```typescript
private getFrontmostApp(): string | null {
  try {
    const result = execSync(
      `osascript -e 'tell application "System Events"' -e 'set fp to first application process whose frontmost is true' -e 'set appName to name of fp' -e 'set bid to bundle identifier of fp' -e 'return appName & "|" & bid' -e 'end tell'`,
      { encoding: 'utf-8', timeout: 1000, stdio: ['pipe', 'pipe', 'pipe'] }
    ).trim()
    const sep = result.indexOf('|')
    if (sep === -1) return null
    const name = result.substring(0, sep).trim()
    const bundleId = result.substring(sep + 1).trim()
    if (name && bundleId && bundleId !== 'com.apple.loginwindow') {
      return JSON.stringify({ name, bundleId })
    }
    return null
  } catch {
    return null
  }
}
```

Key change: Reduce `timeout` from `3000` to `1000`. A 3-second timeout is excessive and could cause the main process to hang if osascript stalls. 1 second is more than enough for this simple query.

Also, optimize `checkImage` to skip the expensive `toPNG()` when the image is empty. The current code already does `if (image.isEmpty()) return` at line 83, which is correct. The real optimization is to avoid `readImage()` entirely when text was the thing that changed. Add a flag:

In the `poll()` method, change:

```typescript
private poll(): void {
  if (this.polling) return
  this.polling = true
  try {
    this.checkText()
    this.checkImage()
  } finally {
    this.polling = false
  }
}
```

to:

```typescript
private poll(): void {
  if (this.polling) return
  this.polling = true
  try {
    const textChanged = this.checkText()
    // Skip image check if text just changed (likely the same clipboard event)
    if (!textChanged) {
      this.checkImage()
    }
  } finally {
    this.polling = false
  }
}
```

And update `checkText` to return a boolean:

Change method signature from:
```typescript
private checkText(): void {
```
to:
```typescript
private checkText(): boolean {
```

Add `return false` at each early return point and `return true` when new text is detected:

```typescript
private checkText(): boolean {
  const text = clipboard.readText()
  if (!text || text.trim().length === 0) return false

  const hash = this.computeHash(text)
  if (hash === this.lastTextHash) return false
  this.lastTextHash = hash

  const existing = repository.getItemByHash(hash)
  if (existing) {
    repository.touchItem(existing.id)
    this.notifyRenderer(existing)
    return true
  }

  const { type, metadata } = detectContentType(text)
  const preview = text.substring(0, 200)

  const item = {
    id: nanoid(),
    content: text,
    content_type: type,
    content_hash: hash,
    preview,
    metadata: metadata ? JSON.stringify(metadata) : null,
    is_favorite: 0,
    is_pinned: 0,
    source_app: this.getFrontmostApp(),
    tags: null,
    category_id: null,
    created_at: Date.now(),
    updated_at: Date.now()
  }

  repository.insertItem(item)
  this.notifyRenderer(item)
  return true
}
```

**Step 2: Build and verify**

Run: `npm run build`

Expected: No errors.

**Step 3: Commit**

```bash
git add src/main/clipboard/monitor.ts
git commit -m "perf: reduce osascript timeout and skip image check when text changed"
```

---

## Summary

| Task | Files | Problem Fixed |
|------|-------|---------------|
| 1 | index.ts, shortcuts.ts | Dynamic imports, excessive delays, blocking execSync |
| 2 | SearchBar.tsx | No search debounce |
| 3 | useSearch.ts | Fuse.js recreation every render |
| 4 | App.tsx | Unconditional reload on panel show |
| 5 | ClipboardItem.tsx | Missing React.memo, hover re-renders |
| 6 | CodePreview.tsx | Shiki highlight cache |
| 7 | monitor.ts | Unnecessary image check, long osascript timeout |
