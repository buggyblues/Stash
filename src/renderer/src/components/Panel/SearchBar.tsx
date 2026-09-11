import { useState, useRef, useEffect, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { useClipboardStore } from '../../stores/clipboardStore'
import { Search, X } from 'lucide-react'
import { Input } from '../ui/input'
import { Button } from '../ui/button'

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
    // Delay to ensure the Electron window has fully gained focus before focusing the input
    const t = setTimeout(() => {
      inputRef.current?.focus()
    }, 0)
    return () => clearTimeout(t)
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
  }, [clipboardSearch])

  return (
    <div className="group relative min-w-0 flex-1">
      <div className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground transition-colors duration-200 group-focus-within:text-primary">
        <Search className="w-4 h-4" />
      </div>
      <Input
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
        className="h-9 rounded-[1rem] border-border/70 bg-muted/50 pl-9 pr-9 shadow-[inset_0_1px_0_rgba(255,255,255,0.35)] focus-visible:border-primary/45 focus-visible:bg-background"
      />
      {localQuery && (
        <Button
          variant="ghost"
          size="icon"
          onClick={handleClear}
          aria-label={t('common.clear')}
          className="absolute right-1 top-1/2 h-6 w-6 -translate-y-1/2 rounded-full text-muted-foreground hover:bg-secondary/80 hover:text-foreground"
        >
          <X className="w-3 h-3" />
        </Button>
      )}
    </div>
  )
}
