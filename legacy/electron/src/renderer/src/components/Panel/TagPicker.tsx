import { useState, useEffect, useRef, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { useTagStore, TagWithCount } from '../../stores/tagStore'
import { useClipboardStore } from '../../stores/clipboardStore'
import { cn } from '../../lib/utils'
import { Tag, Plus, Check } from 'lucide-react'

interface Props {
  itemId: string
  onClose: () => void
}

function toSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-')
}

export default function TagPicker({ itemId, onClose }: Props): React.JSX.Element {
  const { t } = useTranslation()
  const { tags, applyTags, removeTag, loadTags } = useTagStore()
  const loadItems = useClipboardStore((s) => s.loadItems)
  const [query, setQuery] = useState('')
  const [appliedSlugs, setAppliedSlugs] = useState<Set<string>>(new Set())
  const [cursorIndex, setCursorIndex] = useState(0)
  const [similar, setSimilar] = useState<TagWithCount[]>([])
  const inputRef = useRef<HTMLInputElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    window.api.getItemTagSlugs(itemId).then((slugs: string[]) => {
      setAppliedSlugs(new Set(slugs))
    })
    inputRef.current?.focus()
  }, [itemId])

  useEffect(() => {
    if (!query.trim()) {
      setSimilar([])
      return
    }
    window.api.getSimilarTags(query).then((results: TagWithCount[]) => {
      const slug = toSlug(query)
      setSimilar(results.filter((st) => st.slug !== slug))
    })
  }, [query])

  const filteredTags = query.trim()
    ? tags.filter((tag) =>
        tag.slug.includes(toSlug(query)) || tag.name.toLowerCase().includes(query.toLowerCase())
      )
    : tags

  const querySlug = toSlug(query.trim())
  const exactMatch = tags.find((t) => t.slug === querySlug)
  const showCreate = query.trim() && !exactMatch

  const allOptions: Array<{ type: 'tag'; tag: TagWithCount } | { type: 'create' }> = [
    ...filteredTags.map((tag) => ({ type: 'tag' as const, tag })),
    ...(showCreate ? [{ type: 'create' as const }] : [])
  ]

  useEffect(() => {
    setCursorIndex(0)
  }, [query])

  const toggleTag = useCallback(
    async (slug: string) => {
      if (appliedSlugs.has(slug)) {
        await removeTag(itemId, slug)
        setAppliedSlugs((prev) => {
          const next = new Set(prev)
          next.delete(slug)
          return next
        })
      } else {
        await applyTags(itemId, [slug])
        setAppliedSlugs((prev) => new Set([...prev, slug]))
      }
      loadItems()
    },
    [appliedSlugs, itemId, applyTags, removeTag, loadItems]
  )

  const handleCreateAndApply = useCallback(async () => {
    const name = query.trim()
    if (!name) return
    const slug = toSlug(name)
    await applyTags(itemId, [name])
    await loadTags()
    setQuery('')
    setAppliedSlugs((prev) => new Set([...prev, slug]))
    loadItems()
  }, [query, itemId, applyTags, loadTags, loadItems])

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose()
        return
      }
      if (e.key === 'ArrowDown') {
        e.preventDefault()
        setCursorIndex((i) => Math.min(i + 1, allOptions.length - 1))
        return
      }
      if (e.key === 'ArrowUp') {
        e.preventDefault()
        setCursorIndex((i) => Math.max(i - 1, 0))
        return
      }
      if (e.key === 'Enter') {
        e.preventDefault()
        const opt = allOptions[cursorIndex]
        if (!opt) {
          onClose()
          return
        }
        if (opt.type === 'create') {
          handleCreateAndApply()
        } else {
          toggleTag(opt.tag.slug)
        }
        return
      }
    },
    [allOptions, cursorIndex, handleCreateAndApply, toggleTag, onClose]
  )

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent): void => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        onClose()
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [onClose])

  return (
    <div
      ref={containerRef}
      className="absolute z-50 w-64 rounded-xl border border-border/60 bg-popover/85 backdrop-blur-2xl shadow-[0_16px_36px_-6px_rgba(0,0,0,0.3),0_4px_12px_rgba(0,0,0,0.12),inset_0_1px_0_rgba(255,255,255,0.3)] dark:shadow-[0_20px_48px_-8px_rgba(0,0,0,0.8),inset_0_1px_0_rgba(255,255,255,0.12)] overflow-hidden flex flex-col animate-in fade-in-80 zoom-in-95 select-none"
      style={{ maxHeight: 320 }}
    >
      <div className="flex items-center gap-2 px-3 py-2 border-b border-border/50 bg-black/[0.02] dark:bg-white/[0.04]">
        <Tag className="w-3.5 h-3.5 text-muted-foreground shrink-0" />
        <input
          ref={inputRef}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder={t('tagPicker.placeholder')}
          className="flex-1 bg-transparent text-xs text-foreground outline-none placeholder:text-muted-foreground/60"
        />
      </div>

      <div className="overflow-y-auto flex-1 p-1">
        {similar.length > 0 && query.trim() && (
          <div className="px-2 pt-1.5 pb-1">
            <p className="text-[10px] text-muted-foreground uppercase tracking-wider mb-1 px-1">{t('tagPicker.similar')}</p>
            {similar.map((st) => (
              <button
                key={st.slug}
                onClick={() => toggleTag(st.slug)}
                className="w-full flex items-center gap-2 px-2 py-1 text-xs rounded-lg hover:bg-muted/60 text-muted-foreground transition-colors"
              >
                <span>{t('tagPicker.use', { name: st.name })}</span>
                {appliedSlugs.has(st.slug) && <Check className="w-3 h-3 ml-auto text-primary" />}
              </button>
            ))}
            <div className="border-t border-border/40 my-1" />
          </div>
        )}

        {filteredTags.map((tag) => {
          const isSelected = appliedSlugs.has(tag.slug)
          const isCursor = allOptions[cursorIndex]?.type === 'tag' && allOptions[cursorIndex].tag.slug === tag.slug
          return (
            <button
              key={tag.slug}
              onClick={() => toggleTag(tag.slug)}
              className={cn(
                'w-full flex items-center gap-2 px-2.5 py-1.5 text-xs rounded-lg transition-colors',
                isCursor ? 'bg-primary text-primary-foreground' : 'hover:bg-muted/60 text-foreground',
                isSelected && !isCursor && 'font-medium'
              )}
            >
              <Tag className={cn('w-3.5 h-3.5 shrink-0', isCursor ? 'text-primary-foreground/80' : 'text-muted-foreground')} />
              <span className="flex-1 text-left truncate">{tag.name}</span>
              {tag.count > 0 && (
                <span className={cn('text-[10px] tabular-nums', isCursor ? 'text-primary-foreground/70' : 'text-muted-foreground/60')}>{tag.count}</span>
              )}
              {isSelected && <Check className={cn('w-3.5 h-3.5 ml-1', isCursor ? 'text-primary-foreground' : 'text-primary')} />}
            </button>
          )
        })}

        {showCreate && (
          <button
            onClick={handleCreateAndApply}
            className={cn(
              'w-full flex items-center gap-2 px-2.5 py-1.5 text-xs rounded-lg transition-colors border-t border-border/40 mt-1',
              allOptions[cursorIndex]?.type === 'create'
                ? 'bg-primary text-primary-foreground'
                : 'hover:bg-muted/60 text-muted-foreground'
            )}
          >
            <Plus className="w-3.5 h-3.5 shrink-0" />
            <span>{t('tagPicker.create', { name: query.trim() })}</span>
          </button>
        )}

        {filteredTags.length === 0 && !showCreate && (
          <p className="px-3 py-4 text-xs text-center text-muted-foreground">{t('tagPicker.empty')}</p>
        )}
      </div>
    </div>
  )
}
