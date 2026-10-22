import { useState, useRef, useEffect, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { useClipboardStore } from '../../stores/clipboardStore'
import { Search, X } from 'lucide-react'

interface SearchBarProps {
  view: 'clipboard' | 'templates' | 'settings' | 'onboarding'
}

export default function SearchBar({ view }: SearchBarProps): React.JSX.Element {
  const { t } = useTranslation()
  const inputRef = useRef<HTMLInputElement>(null)
  const debounceRef = useRef<ReturnType<typeof setTimeout>>()

  const clipboardSearch = useClipboardStore((state) => state.search)
  const clipboardQuery = useClipboardStore((state) => state.searchQuery)
  const isVisible = useClipboardStore((state) => state.isVisible)

  // Local state drives the input display immediately; debounce triggers actual search
  const [localQuery, setLocalQuery] = useState(clipboardQuery)

  // Sync local state when panel becomes visible (store resets searchQuery to '')
  useEffect(() => {
    if (isVisible) {
      setLocalQuery('')
    }
  }, [isVisible])

  useEffect(() => {
    if (!isVisible || view !== 'clipboard') return
    const timer = setTimeout(() => {
      inputRef.current?.focus()
    }, 0)
    return () => clearTimeout(timer)
  }, [isVisible, view])

  useEffect(() => {
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current)
    }
  }, [])

  const handleChange = useCallback(
    (value: string) => {
      setLocalQuery(value)
      if (debounceRef.current) clearTimeout(debounceRef.current)
      debounceRef.current = setTimeout(() => {
        clipboardSearch(value)
      }, 300)
    },
    [clipboardSearch]
  )

  const handleClear = useCallback(() => {
    setLocalQuery('')
    if (debounceRef.current) clearTimeout(debounceRef.current)
    clipboardSearch('')
    inputRef.current?.focus()
  }, [clipboardSearch])

  return (
    <div className="group relative flex items-center min-w-0 flex-1">
      <div className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground/60 transition-colors duration-150 group-focus-within:text-primary">
        <Search className="w-3.5 h-3.5" />
      </div>
      <input
        ref={inputRef}
        type="text"
        name="clipboard-search"
        value={localQuery}
        onChange={(e) => handleChange(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === 'Escape') {
            inputRef.current?.blur()
          }
        }}
        aria-label={t('panel.search.placeholder')}
        autoComplete="off"
        spellCheck={false}
        placeholder={t('panel.search.placeholder')}
        className="h-8 w-full rounded-full border border-black/[0.08] dark:border-white/[0.12] bg-black/[0.04] dark:bg-white/[0.08] backdrop-blur-md pl-8 pr-8 text-xs text-foreground placeholder:text-muted-foreground/60 transition-all duration-150 shadow-[inset_0_1px_1.5px_rgba(0,0,0,0.06)] focus:border-primary/80 focus:bg-background/95 focus:outline-none focus:ring-2 focus:ring-primary/25"
      />
      {localQuery && (
        <button
          type="button"
          onClick={handleClear}
          aria-label={t('common.clear')}
          className="absolute right-1.5 top-1/2 -translate-y-1/2 flex h-5 w-5 items-center justify-center rounded-full bg-muted-foreground/20 text-muted-foreground hover:bg-muted-foreground/35 hover:text-foreground transition-all duration-150 active:scale-95"
        >
          <X className="w-3 h-3" />
        </button>
      )}
    </div>
  )
}
