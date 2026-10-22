import { useCallback, useState, useRef, useEffect, useMemo, memo, useLayoutEffect } from 'react'
import { useTranslation } from 'react-i18next'
import i18n from '../../i18n'
import { ClipboardItem, useClipboardStore } from '../../stores/clipboardStore'
import { useAppIcon } from '../../hooks/useAppIcon'
import { useClipboardItemContent } from '../../hooks/useClipboardItemContent'
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
  Trash2,
  Tag,
  Pencil
} from 'lucide-react'

interface Props {
  item: ClipboardItem
  index: number
  onDoubleClick?: (itemId: string) => void
  onOpenTagPicker?: (itemId: string) => void
}

const TypeIcon = ({ type, className }: { type: string; className?: string }): React.JSX.Element => {
  const props = { className: className || 'w-3.5 h-3.5 text-muted-foreground/70' }
  switch (type) {
    case 'text':
      return <FileText {...props} />
    case 'code':
      return <Code {...props} />
    case 'url':
      return <Link {...props} />
    case 'color':
      return <Palette {...props} />
    case 'image':
      return <ImageIcon {...props} />
    case 'json':
      return <FileJson {...props} />
    case 'base64':
      return <Lock {...props} />
    case 'file_path':
      return <File {...props} />
    default:
      return <FileText {...props} />
  }
}

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

function ClipboardItemRow({
  item,
  index,
  onDoubleClick,
  onOpenTagPicker
}: Props): React.JSX.Element {
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
    try {
      return JSON.parse(item.source_app) as { name: string; bundleId: string }
    } catch {
      return null
    }
  }, [item.source_app])
  const appIcon = useAppIcon(sourceApp?.bundleId)

  const handleClick = useCallback((e: React.MouseEvent) => {
    if (e.metaKey || e.ctrlKey) {
      // Cmd+Click: toggle multi-select
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

  const rootClassName = cn(
    'group relative mx-1.5 my-0.5 flex cursor-pointer items-center rounded-xl border px-2.5 py-2 transition-all duration-150 select-none',
    isMultiSelected
      ? 'border-primary/40 bg-primary/15 text-foreground shadow-xs'
      : isSelected
        ? 'border-primary/30 dark:border-primary/40 bg-primary/10 dark:bg-primary/15 text-foreground shadow-[inset_0_1px_0_0_rgba(255,255,255,0.6),0_1px_3px_rgba(0,0,0,0.04)] dark:shadow-[inset_0_1px_0_0_rgba(255,255,255,0.08),0_1px_4px_rgba(0,0,0,0.25)]'
        : 'border-transparent bg-transparent text-foreground hover:bg-black/[0.04] dark:hover:bg-white/[0.06]'
  )

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
        className={rootClassName}
      >
        {isSelected && (
          <div className="absolute inset-y-2 left-0.5 w-1 rounded-full bg-primary shadow-[0_0_6px_rgba(var(--primary),0.6)]" />
        )}

        {item.content_type === 'image' ? (
          <ImageRow item={item} index={index} isSelected={isSelected} />
        ) : (
          <>
            <div className="mr-2 flex w-8 shrink-0 items-center justify-center">
              {index < 9 ? (
                <span className={cn(
                  'rounded-md px-1.5 py-0.5 text-[10px] font-mono font-semibold tabular-nums transition-colors',
                  isSelected
                    ? 'bg-primary/20 text-primary'
                    : 'bg-black/[0.04] dark:bg-white/[0.06] text-muted-foreground/80'
                )}>
                  ⌘{index + 1}
                </span>
              ) : (
                <span className="flex h-6 w-6 items-center justify-center rounded-md bg-black/[0.04] dark:bg-white/[0.06] text-muted-foreground/70">
                  <TypeIcon type={item.content_type} className="h-3.5 w-3.5" />
                </span>
              )}
            </div>

            <div className="flex h-full min-w-0 flex-1 flex-col justify-center">
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
                  className="mb-1 w-full border-b border-primary bg-transparent pb-0.5 text-xs font-semibold text-foreground outline-none"
                  placeholder={t('panel.title.placeholder')}
                />
              ) : item.title ? (
                <p
                  className="mb-0.5 cursor-pointer truncate text-xs font-semibold text-primary"
                  onDoubleClick={(e) => {
                    e.stopPropagation()
                    startEditTitle()
                  }}
                >
                  {item.title}
                </p>
              ) : null}
              <p className={cn('truncate text-[12.5px] leading-snug transition-colors', isSelected ? 'font-medium text-foreground' : 'text-foreground/90')}>
                {item.preview || item.content || getContentTypeLabel(t, item.content_type)}
              </p>
              <div className="mt-1 flex min-w-0 items-center gap-1.5 text-[10px] text-muted-foreground/80">
                <span className="rounded-full bg-black/[0.05] dark:bg-white/[0.08] px-1.5 py-0.2 text-[9px] font-medium tracking-wide">
                  {getContentTypeLabel(t, item.content_type)}
                </span>
                <span className="text-muted-foreground/40">•</span>
                <span className="tabular-nums">
                  {formatTime(item.created_at)}
                </span>
                {item.use_count > 0 && (
                  <>
                    <span className="text-muted-foreground/40">•</span>
                    <span className="tabular-nums">{t('panel.item.useCount', { count: item.use_count })}</span>
                  </>
                )}
                {sourceApp && (
                  <>
                    <span className="text-muted-foreground/40">•</span>
                    {appIcon ? (
                      <img
                        src={`data:image/png;base64,${appIcon}`}
                        alt={sourceApp.name}
                        title={sourceApp.name}
                        className="h-3.5 w-3.5 rounded-sm object-contain"
                      />
                    ) : (
                      <span className="max-w-[96px] truncate">{sourceApp.name}</span>
                    )}
                  </>
                )}
              </div>
            </div>
          </>
        )}

        <div className="relative ml-2 flex min-w-[64px] items-center justify-end">
          <div className="absolute inset-0 flex items-center justify-end gap-0.5 opacity-0 transition-opacity duration-150 group-hover:opacity-100">
            <button
              onClick={(e) => {
                e.stopPropagation()
                onOpenTagPicker?.(item.id)
              }}
              aria-label={t('panel.context.tag')}
              className="flex h-6 w-6 items-center justify-center rounded-md border border-black/[0.06] dark:border-white/[0.08] bg-background/80 backdrop-blur-md text-muted-foreground hover:bg-background hover:text-foreground transition-all duration-150 active:scale-90 shadow-2xs"
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
              className={cn(
                'flex h-6 w-6 items-center justify-center rounded-md border border-black/[0.06] dark:border-white/[0.08] bg-background/80 backdrop-blur-md transition-all duration-150 active:scale-90 shadow-2xs',
                item.is_pinned ? 'text-primary' : 'text-muted-foreground hover:bg-background hover:text-foreground'
              )}
            >
              <Pin className="w-3 h-3" />
            </button>
            <button
              onClick={(e) => {
                e.stopPropagation()
                toggleFavorite(item.id)
              }}
              aria-label={item.is_favorite ? t('panel.context.unfavorite') : t('panel.context.favorite')}
              className={cn(
                'flex h-6 w-6 items-center justify-center rounded-md border border-black/[0.06] dark:border-white/[0.08] bg-background/80 backdrop-blur-md transition-all duration-150 active:scale-90 shadow-2xs',
                item.is_favorite ? 'text-amber-500 fill-current' : 'text-muted-foreground hover:bg-background hover:text-foreground'
              )}
            >
              <Star className="w-3 h-3" />
            </button>
          </div>

          <div className="flex items-center gap-1 transition-opacity duration-150 group-hover:opacity-0">
            {inQueue && (
              <span className="inline-flex h-4 w-4 items-center justify-center rounded-full bg-primary text-[9px] font-bold text-primary-foreground shadow-xs">
                {queuePos}
              </span>
            )}
            {item.is_pinned !== 0 && <Pin className="w-3 h-3 text-primary" />}
            {item.is_favorite !== 0 && <Star className="w-3 h-3 text-amber-500 fill-amber-500" />}
            {hasTag && <Tag className="w-3 h-3 text-primary/80" />}
          </div>
        </div>
      </div>

      {contextMenu && (
        <div
          ref={menuRef}
          className="fixed z-50 max-w-[calc(100vw-24px)] min-w-[140px] overflow-hidden rounded-xl border border-border/60 bg-popover/85 backdrop-blur-2xl p-1 text-popover-foreground shadow-[0_16px_36px_-6px_rgba(0,0,0,0.3),0_4px_12px_rgba(0,0,0,0.12),inset_0_1px_0_rgba(255,255,255,0.3)] dark:shadow-[0_20px_48px_-8px_rgba(0,0,0,0.8),inset_0_1px_0_rgba(255,255,255,0.12)] animate-in fade-in-80 zoom-in-95"
          style={menuPosition ?? { left: contextMenu.x, top: contextMenu.y }}
        >
          <ContextMenuItem
            icon={<Pencil className="h-3.5 w-3.5" />}
            label={t('panel.context.editTitle')}
            onClick={() => {
              startEditTitle()
              setContextMenu(null)
            }}
          />
          <div className="-mx-1 my-1 h-px bg-border/40" />
          <ContextMenuItem
            icon={<Trash2 className="h-3.5 w-3.5" />}
            label={t('panel.context.delete')}
            danger
            onClick={() => {
              deleteItem(item.id)
              setContextMenu(null)
            }}
          />
        </div>
      )}
    </>
  )
}

export default memo(ClipboardItemRow)

function ImageRow({
  item,
  index,
  isSelected
}: {
  item: ClipboardItem
  index: number
  isSelected: boolean
}): React.JSX.Element {
  const content = useClipboardItemContent(item.id, item.content)
  const src = content
    ? content.startsWith('/')
      ? `file://${content}`
      : `data:image/png;base64,${content}`
    : null

  return (
    <div className="flex w-full min-w-0 items-center gap-2.5">
      <div className="flex w-8 shrink-0 items-center justify-center">
        {index < 9 ? (
          <span className={cn(
            'rounded-md px-1.5 py-0.5 text-[10px] font-mono font-semibold tabular-nums transition-colors',
            isSelected
              ? 'bg-primary/20 text-primary'
              : 'bg-black/[0.04] dark:bg-white/[0.06] text-muted-foreground/80'
          )}>
            ⌘{index + 1}
          </span>
        ) : (
          <span className="flex h-6 w-6 items-center justify-center rounded-md bg-black/[0.04] dark:bg-white/[0.06] text-muted-foreground/70">
            <ImageIcon className="h-3.5 w-3.5" />
          </span>
        )}
      </div>
      {src ? (
        <img
          src={src}
          alt=""
          className="h-12 w-[4.5rem] shrink-0 rounded-lg border border-border/50 object-cover shadow-2xs"
          loading="lazy"
        />
      ) : (
        <div className="flex h-12 w-[4.5rem] shrink-0 items-center justify-center rounded-lg border border-border/50 bg-black/[0.03] dark:bg-white/[0.06] text-muted-foreground">
          <ImageIcon className="h-4 w-4" />
        </div>
      )}
      <div className="flex-1 min-w-0">
        <p className={cn('truncate text-[12.5px] leading-snug', isSelected ? 'font-medium text-foreground' : 'text-foreground/90')}>
          {item.preview || i18n.t('panel.image.fallback')}
        </p>
        <div className="mt-1 flex items-center gap-1.5 text-[10px] text-muted-foreground/80">
          <span className="rounded-full bg-black/[0.05] dark:bg-white/[0.08] px-1.5 py-0.2 text-[9px] font-medium tracking-wide">
            {i18n.t('panel.filter.image')}
          </span>
          <span className="text-muted-foreground/40">•</span>
          <span>{formatTime(item.created_at)}</span>
        </div>
      </div>
    </div>
  )
}

function ContextMenuItem({
  icon,
  label,
  onClick,
  danger
}: {
  icon?: React.ReactNode
  label: string
  onClick: () => void
  danger?: boolean
}): React.JSX.Element {
  return (
    <button
      onClick={onClick}
      className={cn(
        "relative flex w-full cursor-default select-none items-center rounded-lg px-2.5 py-1.5 text-xs outline-none transition-colors duration-100",
        danger
          ? "text-destructive hover:bg-destructive hover:text-destructive-foreground"
          : "hover:bg-primary hover:text-primary-foreground"
      )}
    >
      {icon && <span className="mr-2 h-3.5 w-3.5 opacity-80">{icon}</span>}
      <span>{label}</span>
    </button>
  )
}
