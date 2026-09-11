import { useEffect, useRef, useState, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { useClipboardStore } from '../../stores/clipboardStore'
import { useTagStore } from '../../stores/tagStore'
import { Badge } from '../ui/badge'
import { cn } from '../../lib/utils'
import { Star, ArrowDownWideNarrow } from 'lucide-react'

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
    <div className="surface-subtle relative flex items-center border-b border-border/60 px-1">
      {canScrollLeft && (
        <button
          onClick={() => scroll('left')}
          aria-label={t('panel.tagBar.scrollLeft')}
          className="absolute left-0 z-10 flex h-full items-center px-1 text-muted-foreground transition-colors hover:text-foreground"
        >
          <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m15 18-6-6 6-6"/></svg>
        </button>
      )}

      <div
        ref={scrollRef}
        className="no-scrollbar flex items-center gap-1.5 overflow-x-auto px-1.5 py-1.5"
      >
        <Badge
          variant={isAll ? 'default' : 'secondary'}
          className={cn(
            'shrink-0 cursor-pointer whitespace-nowrap border px-2.5 py-1 text-[11px]',
            !isAll &&
              'border-transparent bg-transparent text-muted-foreground hover:border-border/60 hover:bg-background/65 hover:text-foreground'
          )}
          onClick={() => setLeftFilter({ type: 'all' })}
        >
          {t('common.all')}
        </Badge>

        <Badge
          variant={isStarred ? 'default' : 'secondary'}
          className={cn(
            'shrink-0 cursor-pointer whitespace-nowrap border px-2.5 py-1 text-[11px] gap-1',
            !isStarred &&
              'border-transparent bg-transparent text-muted-foreground hover:border-border/60 hover:bg-background/65 hover:text-foreground'
          )}
          onClick={() => {
            if (isStarred) {
              setLeftFilter({ type: 'all' })
            } else {
              setLeftFilter({ type: 'starred' })
            }
          }}
        >
          <Star className="h-3 w-3" aria-hidden="true" />
          {t('panel.tagBar.starred')}
          {starredCount > 0 && (
            <span className="ml-0.5 text-[9px] tabular-nums opacity-60">{starredCount}</span>
          )}
        </Badge>

        <Badge
          variant={sortBy === 'usage' ? 'default' : 'secondary'}
          className={cn(
            'shrink-0 flex cursor-pointer items-center gap-1 whitespace-nowrap border px-2.5 py-1 text-[11px]',
            sortBy !== 'usage' &&
              'border-transparent bg-transparent text-muted-foreground hover:border-border/60 hover:bg-background/65 hover:text-foreground'
          )}
          onClick={() => setSortBy(sortBy === 'usage' ? 'recent' : 'usage')}
        >
          <ArrowDownWideNarrow className="h-3 w-3" aria-hidden="true" />
          {t('panel.filter.byUsage')}
        </Badge>

        {tags.length > 0 && (
          <div className="h-4 w-px shrink-0 bg-border/70" />
        )}

        {tags.map((tag) => {
          const isActive = activeTag === tag.slug
          return (
            <Badge
              key={tag.slug}
              variant={isActive ? 'default' : 'secondary'}
              className={cn(
                'shrink-0 cursor-pointer whitespace-nowrap border px-2.5 py-1 text-[11px]',
                !isActive &&
                  'border-transparent bg-transparent text-muted-foreground hover:border-border/60 hover:bg-background/65 hover:text-foreground'
              )}
              onClick={() => {
                if (isActive) {
                  setLeftFilter({ type: 'all' })
                } else {
                  setLeftFilter({ type: 'tag', slug: tag.slug })
                }
              }}
            >
              {tag.name}
              {tag.count > 0 && (
                <span className="ml-1 text-[9px] tabular-nums opacity-60">{tag.count}</span>
              )}
            </Badge>
          )
        })}
      </div>

      {canScrollRight && (
        <button
          onClick={() => scroll('right')}
          aria-label={t('panel.tagBar.scrollRight')}
          className="absolute right-0 z-10 flex h-full items-center px-1 text-muted-foreground transition-colors hover:text-foreground"
        >
          <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m9 18 6-6-6-6"/></svg>
        </button>
      )}
    </div>
  )
}
