import { useRef, useEffect, useCallback, useMemo, memo, useState, useLayoutEffect } from 'react'
import { useTranslation } from 'react-i18next'
import i18n from '../../i18n'
import { ClipboardItem, useClipboardStore } from '../../stores/clipboardStore'
import { useSearch } from '../../hooks/useSearch'
import { useAppIcon } from '../../hooks/useAppIcon'
import { useClipboardItemContent } from '../../hooks/useClipboardItemContent'
import CodePreview from '../Preview/CodePreview'
import JsonPreview from '../Preview/JsonPreview'
import ColorPreview from '../Preview/ColorPreview'
import ImagePreview from '../Preview/ImagePreview'
import { cn } from '../../lib/utils'
import { getContentTypeLabel } from '../../utils/contentType'
import { getContextMenuPosition } from '../../utils/contextMenu'
import {
  FileText,
  Code,
  Link,
  Palette,
  Image as ImageIcon,
  FileJson,
  Lock,
  File,
  Pin,
  Star,
  Tag,
  Pencil,
  Trash2
} from 'lucide-react'

const CARD_WIDTH = 280
const CARD_GAP = 12

function formatTime(timestamp: number): string {
  const now = Date.now()
  const diff = now - timestamp
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(diff / 3600000)
  const days = Math.floor(diff / 86400000)

  if (minutes < 1) return i18n.t('time.justNow')
  if (minutes < 60) return i18n.t('time.minutesAgo', { count: minutes })
  if (hours < 24) return i18n.t('time.hoursAgo', { count: hours })
  return i18n.t('time.daysAgo', { count: days })
}

const TypeIcon = ({ type, className }: { type: string; className?: string }): React.JSX.Element => {
  const props = { className: className || 'w-3.5 h-3.5' }
  switch (type) {
    case 'text': return <FileText {...props} />
    case 'code': return <Code {...props} />
    case 'url': return <Link {...props} />
    case 'color': return <Palette {...props} />
    case 'image': return <ImageIcon {...props} />
    case 'json': return <FileJson {...props} />
    case 'base64': return <Lock {...props} />
    case 'file_path': return <File {...props} />
    default: return <FileText {...props} />
  }
}

function CardPreviewContent({
  item,
  rootRef
}: {
  item: ClipboardItem
  rootRef: React.RefObject<HTMLDivElement | null>
}): React.JSX.Element {
  const contentRef = useRef<HTMLDivElement>(null)
  const [isNearViewport, setIsNearViewport] = useState(false)
  const content = useClipboardItemContent(item.id, item.content, isNearViewport)

  useEffect(() => {
    if (content || !contentRef.current) return
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          setIsNearViewport(true)
          observer.disconnect()
        }
      },
      { root: rootRef.current, rootMargin: '160px' }
    )
    observer.observe(contentRef.current)
    return () => observer.disconnect()
  }, [content, rootRef])

  const resolvedItem = content === item.content ? item : { ...item, content }
  const metadata = useMemo(() => {
    if (!resolvedItem.metadata) return {}
    try { return JSON.parse(resolvedItem.metadata) } catch { return {} }
  }, [resolvedItem.metadata])

  if (!content) {
    return (
      <div ref={contentRef} className="h-full overflow-auto p-3 font-mono text-[11px] leading-relaxed text-foreground/70">
        {item.preview || ''}
      </div>
    )
  }

  let preview: React.JSX.Element
  switch (resolvedItem.content_type) {
    case 'code':
      preview = <CodePreview code={resolvedItem.content} language={metadata.language || 'plaintext'} />
      break
    case 'json':
      preview = <JsonPreview content={resolvedItem.content} />
      break
    case 'color':
      preview = <ColorPreview content={resolvedItem.content} />
      break
    case 'image':
      preview = <ImagePreview content={resolvedItem.content} metadata={resolvedItem.metadata} />
      break
    default:
      preview = (
        <pre className="whitespace-pre-wrap break-all p-3 font-mono text-[11px] leading-relaxed text-foreground/90">
          {resolvedItem.content}
        </pre>
      )
  }

  return <div ref={contentRef} className="h-full overflow-auto">{preview}</div>
}

const ClipboardCard = memo(function ClipboardCard({
  item,
  index,
  rootRef,
  onDoubleClick,
  onOpenTagPicker
}: {
  item: ClipboardItem
  index: number
  rootRef: React.RefObject<HTMLDivElement | null>
  onDoubleClick?: (itemId: string) => void
  onOpenTagPicker?: (itemId: string) => void
}): React.JSX.Element {
  const { t } = useTranslation()
  const isSelected = useClipboardStore((s) => s.selectedIndex === index)
  const setSelectedIndex = useClipboardStore((s) => s.setSelectedIndex)
  const pasteItem = useClipboardStore((s) => s.pasteItem)
  const deleteItem = useClipboardStore((s) => s.deleteItem)
  const toggleFavorite = useClipboardStore((s) => s.toggleFavorite)
  const togglePin = useClipboardStore((s) => s.togglePin)
  const toggleSelectItem = useClipboardStore((s) => s.toggleSelectItem)
  const updateTitle = useClipboardStore((s) => s.updateTitle)
  const inQueue = useClipboardStore((s) => s.sequenceQueue.some((q) => q.id === item.id))
  const queuePos = useClipboardStore((s) => {
    if (!inQueue) return 0
    return s.sequenceQueue.findIndex((q) => q.id === item.id) + 1
  })
  const isMultiSelected = useClipboardStore((s) => s.selectedItems.has(item.id))
  const hasTag = !!item.tag_slugs
  const [contextMenu, setContextMenu] = useState<{ x: number; y: number } | null>(null)
  const [menuPosition, setMenuPosition] = useState<{ left: number; top: number } | null>(null)
  const [isEditingTitle, setIsEditingTitle] = useState(false)
  const [editingTitle, setEditingTitle] = useState('')
  const titleInputRef = useRef<HTMLInputElement>(null)
  const menuRef = useRef<HTMLDivElement>(null)

  const sourceApp = useMemo(() => {
    if (!item.source_app) return null
    try { return JSON.parse(item.source_app) as { name: string; bundleId: string } } catch { return null }
  }, [item.source_app])
  const appIcon = useAppIcon(sourceApp?.bundleId)

  const handleClick = useCallback((e: React.MouseEvent) => {
    if (e.metaKey || e.ctrlKey) {
      e.preventDefault()
      toggleSelectItem(item.id)
      return
    }
    setSelectedIndex(index)
    pasteItem(item.id)
  }, [index, item.id, setSelectedIndex, pasteItem, toggleSelectItem])

  const handleContextMenu = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault()
      e.stopPropagation()
      setSelectedIndex(index)
      setContextMenu({ x: e.clientX, y: e.clientY })
    },
    [index, setSelectedIndex]
  )

  const startEditTitle = useCallback(() => {
    setEditingTitle(item.title || '')
    setIsEditingTitle(true)
  }, [item.title])

  const saveTitle = useCallback(() => {
    const trimmed = editingTitle.trim()
    updateTitle(item.id, trimmed || null)
    setIsEditingTitle(false)
  }, [editingTitle, item.id, updateTitle])

  useEffect(() => {
    if (isEditingTitle && titleInputRef.current) {
      titleInputRef.current.focus()
      titleInputRef.current.select()
    }
  }, [isEditingTitle])

  useEffect(() => {
    if (!contextMenu) return
    const handleClickOutside = (e: MouseEvent): void => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setContextMenu(null)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [contextMenu])

  useLayoutEffect(() => {
    if (!contextMenu || !menuRef.current) {
      setMenuPosition(null)
      return
    }

    const rect = menuRef.current.getBoundingClientRect()
    setMenuPosition(
      getContextMenuPosition(
        contextMenu,
        { width: rect.width, height: rect.height },
        { width: window.innerWidth, height: window.innerHeight }
      )
    )
  }, [contextMenu])

  return (
    <>
      <div
        onClick={handleClick}
        onDoubleClick={(e) => {
          e.stopPropagation()
          onDoubleClick?.(item.id)
        }}
        onContextMenu={handleContextMenu}
        onMouseEnter={() => setSelectedIndex(index)}
        className={cn(
          'group flex h-full shrink-0 cursor-pointer flex-col overflow-hidden rounded-xl border transition-all duration-150 select-none',
          isMultiSelected
            ? 'border-primary/40 bg-primary/15 shadow-sm'
            : isSelected
              ? 'border-primary/40 bg-card/90 dark:bg-card/70 shadow-[0_8px_24px_-4px_rgba(var(--primary),0.25),inset_0_1px_0_rgba(255,255,255,0.7)] scale-[1.015]'
              : 'border-border/50 bg-card/60 backdrop-blur-md hover:border-border/80 hover:bg-card/85 shadow-2xs'
        )}
        style={{ width: CARD_WIDTH }}
      >
        {/* Card header */}
        <div className="flex items-center gap-2 border-b border-border/40 px-3 py-2">
          <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-muted text-muted-foreground">
            <TypeIcon type={item.content_type} className="h-3 w-3" />
          </span>
          {isEditingTitle ? (
            <input
              ref={titleInputRef}
              value={editingTitle}
              onChange={(e) => setEditingTitle(e.target.value)}
              onBlur={saveTitle}
              onKeyDown={(e) => {
                if (e.key === 'Enter') saveTitle()
                if (e.key === 'Escape') setIsEditingTitle(false)
                e.stopPropagation()
              }}
              onClick={(e) => e.stopPropagation()}
              aria-label={t('panel.context.editTitle')}
              className="min-w-0 flex-1 border-b border-primary bg-transparent pb-0.5 text-[11px] font-semibold text-foreground outline-none"
              placeholder={t('panel.title.placeholder')}
            />
          ) : (
            <span className="truncate text-[11px] font-semibold text-foreground/90">
              {item.title || item.preview || getContentTypeLabel(t, item.content_type)}
            </span>
          )}
          <div className="relative ml-auto flex min-w-[52px] items-center justify-end">
            {/* Hover action buttons */}
            <div className="absolute inset-0 flex items-center justify-end gap-0.5 bg-inherit opacity-0 transition-opacity duration-200 group-hover:opacity-100">
              <button
                onClick={(e) => {
                  e.stopPropagation()
                  onOpenTagPicker?.(item.id)
                }}
                aria-label={t('panel.context.tag')}
                className="rounded-full p-0.5 text-muted-foreground transition-colors hover:bg-secondary/85 hover:text-foreground"
                title={t('panel.context.tag')}
              >
                <Tag className="w-3 h-3" />
              </button>
              <button
                onClick={(e) => {
                  e.stopPropagation()
                  togglePin(item.id)
                }}
                aria-label={item.is_pinned ? t('panel.context.unpin') : t('panel.context.pin')}
                className={`rounded-full p-0.5 transition-colors hover:bg-secondary/85 ${
                  item.is_pinned ? 'text-primary' : 'text-muted-foreground'
                }`}
              >
                <Pin className="w-3 h-3" />
              </button>
              <button
                onClick={(e) => {
                  e.stopPropagation()
                  toggleFavorite(item.id)
                }}
                aria-label={item.is_favorite ? t('panel.context.unfavorite') : t('panel.context.favorite')}
                className={`rounded-full p-0.5 transition-colors hover:bg-secondary/85 ${
                  item.is_favorite ? 'text-yellow-500' : 'text-muted-foreground'
                }`}
              >
                <Star className="w-3 h-3" />
              </button>
            </div>

            {/* Static indicator icons */}
            <div className="flex items-center gap-0.5 transition-opacity duration-200 group-hover:opacity-0">
              {inQueue && (
                <span className="inline-flex h-4 w-4 items-center justify-center rounded-full bg-primary text-[9px] font-bold text-primary-foreground">
                  {queuePos}
                </span>
              )}
              {item.is_pinned !== 0 && <Pin className="w-3 h-3 text-primary" />}
              {item.is_favorite !== 0 && <Star className="w-3 h-3 text-yellow-500" />}
              {hasTag && <Tag className="w-3 h-3 text-primary" />}
            </div>
          </div>
        </div>

        {/* Card content — the preview */}
        <div className="flex-1 overflow-auto">
          <CardPreviewContent item={item} rootRef={rootRef} />
        </div>

        {/* Card footer */}
        <div className="flex items-center gap-1.5 border-t border-border/40 px-3 py-1.5 text-[10px] text-muted-foreground">
          <span className="rounded-full bg-primary/15 text-foreground px-1.5 py-0.5 uppercase tracking-[0.14em] text-[9px]">
            {getContentTypeLabel(t, item.content_type)}
          </span>
          <span className="text-muted-foreground/50">•</span>
          <span>{formatTime(item.created_at)}</span>
          {item.use_count > 0 && (
            <>
              <span className="text-muted-foreground/50">•</span>
              <span className="tabular-nums">{t('panel.item.useCount', { count: item.use_count })}</span>
            </>
          )}
          {sourceApp && appIcon && (
            <>
              <span className="text-muted-foreground/50">•</span>
              <img
                src={`data:image/png;base64,${appIcon}`}
                alt={sourceApp.name}
                title={sourceApp.name}
                className="h-3.5 w-3.5 rounded-sm"
              />
            </>
          )}
        </div>
      </div>

      {contextMenu && (
        <div
          ref={menuRef}
          className="fixed z-50 max-w-[calc(100vw-24px)] min-w-[140px] overflow-hidden rounded-xl border border-border/60 bg-popover/85 backdrop-blur-2xl p-1 text-popover-foreground shadow-[0_16px_36px_-6px_rgba(0,0,0,0.3),0_4px_12px_rgba(0,0,0,0.12),inset_0_1px_0_rgba(255,255,255,0.3)] dark:shadow-[0_20px_48px_-8px_rgba(0,0,0,0.8),inset_0_1px_0_rgba(255,255,255,0.12)] animate-in fade-in-80 zoom-in-95 select-none"
          style={menuPosition ?? { left: contextMenu.x, top: contextMenu.y }}
        >
          <button
            onClick={() => {
              onOpenTagPicker?.(item.id)
              setContextMenu(null)
            }}
            className="relative flex w-full cursor-default select-none items-center rounded-lg px-2.5 py-1.5 text-xs outline-none transition-colors duration-100 hover:bg-primary hover:text-primary-foreground"
          >
            <span className="mr-2 h-3.5 w-3.5 opacity-80"><Tag className="h-3.5 w-3.5" /></span>
            <span>{t('panel.context.tag')}</span>
          </button>
          <button
            onClick={() => {
              togglePin(item.id)
              setContextMenu(null)
            }}
            className="relative flex w-full cursor-default select-none items-center rounded-lg px-2.5 py-1.5 text-xs outline-none transition-colors duration-100 hover:bg-primary hover:text-primary-foreground"
          >
            <span className="mr-2 h-3.5 w-3.5 opacity-80"><Pin className="h-3.5 w-3.5" /></span>
            <span>{item.is_pinned ? t('panel.context.unpin') : t('panel.context.pin')}</span>
          </button>
          <button
            onClick={() => {
              toggleFavorite(item.id)
              setContextMenu(null)
            }}
            className="relative flex w-full cursor-default select-none items-center rounded-lg px-2.5 py-1.5 text-xs outline-none transition-colors duration-100 hover:bg-primary hover:text-primary-foreground"
          >
            <span className="mr-2 h-3.5 w-3.5 opacity-80"><Star className="h-3.5 w-3.5" /></span>
            <span>{item.is_favorite ? t('panel.context.unfavorite') : t('panel.context.favorite')}</span>
          </button>
          <button
            onClick={() => {
              startEditTitle()
              setContextMenu(null)
            }}
            className="relative flex w-full cursor-default select-none items-center rounded-lg px-2.5 py-1.5 text-xs outline-none transition-colors duration-100 hover:bg-primary hover:text-primary-foreground"
          >
            <span className="mr-2 h-3.5 w-3.5 opacity-80"><Pencil className="h-3.5 w-3.5" /></span>
            <span>{t('panel.context.editTitle')}</span>
          </button>
          <div className="-mx-1 my-1 h-px bg-border/40" />
          <button
            onClick={() => {
              deleteItem(item.id)
              setContextMenu(null)
            }}
            className="relative flex w-full cursor-default select-none items-center rounded-lg px-2.5 py-1.5 text-xs text-destructive outline-none transition-colors duration-100 hover:bg-destructive hover:text-destructive-foreground"
          >
            <span className="mr-2 h-3.5 w-3.5 opacity-80"><Trash2 className="h-3.5 w-3.5" /></span>
            <span>{t('panel.context.delete')}</span>
          </button>
        </div>
      )}
    </>
  )
})

export default function ClipboardCardList({ onDoubleClick, onOpenTagPicker }: {
  onDoubleClick?: (itemId: string) => void
  onOpenTagPicker?: (itemId: string) => void
}): React.JSX.Element {
  const items = useSearch()
  const { t } = useTranslation()
  const scrollRef = useRef<HTMLDivElement>(null)

  // Scroll selected card into view
  useEffect(() => {
    return useClipboardStore.subscribe((state, prev) => {
      if (state.selectedIndex === (prev as typeof state).selectedIndex) return
      const el = scrollRef.current
      if (!el) return
      const idx = state.selectedIndex
      const cardLeft = idx * (CARD_WIDTH + CARD_GAP)
      const cardRight = cardLeft + CARD_WIDTH
      const viewLeft = el.scrollLeft
      const viewRight = viewLeft + el.clientWidth

      if (cardLeft < viewLeft) {
        el.scrollTo({ left: cardLeft - CARD_GAP, behavior: 'smooth' })
      } else if (cardRight > viewRight) {
        el.scrollTo({ left: cardRight - el.clientWidth + CARD_GAP, behavior: 'smooth' })
      }
    })
  }, [])

  if (items.length === 0) {
    return (
      <div className="flex flex-1 items-center justify-center px-5 py-8 text-sm text-muted-foreground">
        <div className="max-w-xs rounded-[1.25rem] border border-border/60 bg-card px-6 py-8 text-center shadow-sm">
          <p className="mb-3 text-3xl">📋</p>
          <p className="text-base font-semibold text-foreground">{t('panel.empty.title')}</p>
          <p className="mt-2 text-xs leading-6 text-muted-foreground">{t('panel.empty.subtitle')}</p>
        </div>
      </div>
    )
  }

  return (
    <div
      ref={scrollRef}
      className="no-scrollbar flex flex-1 items-stretch gap-3 overflow-x-auto px-3 py-3"
    >
      {items.map((item, index) => (
        <ClipboardCard
          key={item.id}
          item={item}
          index={index}
          rootRef={scrollRef}
          onDoubleClick={onDoubleClick}
          onOpenTagPicker={onOpenTagPicker}
        />
      ))}
    </div>
  )
}
