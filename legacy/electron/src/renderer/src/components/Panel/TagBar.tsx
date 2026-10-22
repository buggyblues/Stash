import { useEffect, useRef, useState, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { useClipboardStore } from '../../stores/clipboardStore'
import { useTagStore } from '../../stores/tagStore'
import { cn } from '../../lib/utils'
import { Star, ArrowDownWideNarrow, ChevronLeft, ChevronRight } from 'lucide-react'

export default function TagBar(): React.JSX.Element {
  const { t } = useTranslation()
  const { leftFilter, setLeftFilter, starredCount, tagBarCollapsed, sortBy, setSortBy } = useClipboardStore()
  const { tags, loadTags } = useTagStore()
  const scrollRef = useRef<HTMLDivElement>(null)
  const [canScrollLeft, setCanScrollLeft] = useState(false)
  const [canScrollRight, setCanScrollRight] = useState(false)

  useEffect(() => {
    loadTags()
  }, [loadTags, leftFilter])

  const checkScroll = useCallback(() => {
    const el = scrollRef.current
    if (!el) return
    setCanScrollLeft(el.scrollLeft > 0)
    setCanScrollRight(el.scrollLeft + el.clientWidth < el.scrollWidth - 1)
  }, [])

  useEffect(() => {
    const el = scrollRef.current
    if (!el) return
    checkScroll()
    el.addEventListener('scroll', checkScroll, { passive: true })
    const observer = new ResizeObserver(checkScroll)
    observer.observe(el)
    return () => {
      el.removeEventListener('scroll', checkScroll)
      observer.disconnect()
    }
  }, [checkScroll, tags])

  const scroll = (direction: 'left' | 'right'): void => {
    const el = scrollRef.current
    if (!el) return
    el.scrollBy({ left: direction === 'left' ? -120 : 120, behavior: 'smooth' })
  }

  if (tagBarCollapsed) return <></>

  const isAll = leftFilter.type === 'all'
  const isStarred = leftFilter.type === 'starred'
  const activeTag = leftFilter.type === 'tag' ? leftFilter.slug : null

  return (
    <div className="surface-subtle relative flex items-center border-b border-border/50 px-1 py-1">
      {canScrollLeft && (
        <button
          onClick={() => scroll('left')}
          aria-label={t('panel.tagBar.scrollLeft')}
          className="absolute left-0.5 z-10 flex h-6 w-5 items-center justify-center rounded-md bg-background/80 backdrop-blur-md shadow-sm text-muted-foreground transition-colors hover:text-foreground active:scale-95"
        >
          <ChevronLeft className="h-3.5 w-3.5" />
        </button>
      )}

      <div
        ref={scrollRef}
        className="no-scrollbar flex items-center gap-1 overflow-x-auto px-1.5 py-0.5"
      >
        <button
          type="button"
          onClick={() => setLeftFilter({ type: 'all' })}
          className={cn(
            'shrink-0 flex items-center whitespace-nowrap rounded-full px-2.5 py-0.5 text-[11px] font-medium transition-all duration-150 active:scale-95',
            isAll
              ? 'bg-primary text-primary-foreground shadow-[inset_0_1px_0_0_rgba(255,255,255,0.3),0_1px_2px_rgba(0,0,0,0.12)]'
              : 'border border-black/[0.06] dark:border-white/[0.08] bg-black/[0.03] dark:bg-white/[0.06] text-muted-foreground hover:bg-black/[0.06] dark:hover:bg-white/[0.12] hover:text-foreground'
          )}
        >
          {t('common.all')}
        </button>

        <button
          type="button"
          onClick={() => {
            if (isStarred) {
              setLeftFilter({ type: 'all' })
            } else {
              setLeftFilter({ type: 'starred' })
            }
          }}
          className={cn(
            'shrink-0 flex items-center gap-1 whitespace-nowrap rounded-full px-2.5 py-0.5 text-[11px] font-medium transition-all duration-150 active:scale-95',
            isStarred
              ? 'bg-primary text-primary-foreground shadow-[inset_0_1px_0_0_rgba(255,255,255,0.3),0_1px_2px_rgba(0,0,0,0.12)]'
              : 'border border-black/[0.06] dark:border-white/[0.08] bg-black/[0.03] dark:bg-white/[0.06] text-muted-foreground hover:bg-black/[0.06] dark:hover:bg-white/[0.12] hover:text-foreground'
          )}
        >
          <Star className={cn('h-3 w-3', isStarred ? 'fill-current' : 'text-amber-500')} aria-hidden="true" />
          <span>{t('panel.tagBar.starred')}</span>
          {starredCount > 0 && (
            <span className="ml-0.5 rounded-full bg-black/10 dark:bg-white/15 px-1 text-[9px] tabular-nums font-semibold">
              {starredCount}
            </span>
          )}
        </button>

        <button
          type="button"
          onClick={() => setSortBy(sortBy === 'usage' ? 'recent' : 'usage')}
          className={cn(
            'shrink-0 flex items-center gap-1 whitespace-nowrap rounded-full px-2.5 py-0.5 text-[11px] font-medium transition-all duration-150 active:scale-95',
            sortBy === 'usage'
              ? 'bg-primary text-primary-foreground shadow-[inset_0_1px_0_0_rgba(255,255,255,0.3),0_1px_2px_rgba(0,0,0,0.12)]'
              : 'border border-black/[0.06] dark:border-white/[0.08] bg-black/[0.03] dark:bg-white/[0.06] text-muted-foreground hover:bg-black/[0.06] dark:hover:bg-white/[0.12] hover:text-foreground'
          )}
        >
          <ArrowDownWideNarrow className="h-3 w-3" aria-hidden="true" />
          <span>{t('panel.filter.byUsage')}</span>
        </button>

        {tags.length > 0 && (
          <div className="h-3.5 w-px shrink-0 bg-border/60 mx-0.5" />
        )}

        {tags.map((tag) => {
          const isActive = activeTag === tag.slug
          return (
            <button
              key={tag.slug}
              type="button"
              onClick={() => {
                if (isActive) {
                  setLeftFilter({ type: 'all' })
                } else {
                  setLeftFilter({ type: 'tag', slug: tag.slug })
                }
              }}
              className={cn(
                'shrink-0 flex items-center whitespace-nowrap rounded-full px-2.5 py-0.5 text-[11px] font-medium transition-all duration-150 active:scale-95',
                isActive
                  ? 'bg-primary text-primary-foreground shadow-[inset_0_1px_0_0_rgba(255,255,255,0.3),0_1px_2px_rgba(0,0,0,0.12)]'
                  : 'border border-black/[0.06] dark:border-white/[0.08] bg-black/[0.03] dark:bg-white/[0.06] text-muted-foreground hover:bg-black/[0.06] dark:hover:bg-white/[0.12] hover:text-foreground'
              )}
            >
              <span>{tag.name}</span>
              {tag.count > 0 && (
                <span className="ml-1 rounded-full bg-black/10 dark:bg-white/15 px-1 text-[9px] tabular-nums font-semibold">
                  {tag.count}
                </span>
              )}
            </button>
          )
        })}
      </div>

      {canScrollRight && (
        <button
          onClick={() => scroll('right')}
          aria-label={t('panel.tagBar.scrollRight')}
          className="absolute right-0.5 z-10 flex h-6 w-5 items-center justify-center rounded-md bg-background/80 backdrop-blur-md shadow-sm text-muted-foreground transition-colors hover:text-foreground active:scale-95"
        >
          <ChevronRight className="h-3.5 w-3.5" />
        </button>
      )}
    </div>
  )
}
