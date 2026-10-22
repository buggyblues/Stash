import { useCallback, useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Clipboard,
  Pin,
  X,
  FileText,
  Code,
  Link,
  Braces,
  Palette,
  Image as ImageIcon
} from 'lucide-react'
import { cn } from '../../lib/utils'

interface ClipboardItem {
  id: string
  content: string
  content_type: string
  preview: string | null
}

function ContentTypeIcon({ type }: { type: string }): React.JSX.Element {
  const className = 'w-3 h-3 text-muted-foreground/60 shrink-0'
  switch (type) {
    case 'code':
      return <Code className={className} />
    case 'url':
      return <Link className={className} />
    case 'json':
      return <Braces className={className} />
    case 'color':
      return <Palette className={className} />
    case 'image':
      return <ImageIcon className={className} />
    default:
      return <FileText className={className} />
  }
}

function truncate(text: string, max: number): string {
  return text.length > max ? text.slice(0, max) + '…' : text
}

function WidgetPanel(): React.JSX.Element {
  const { t } = useTranslation()
  const [items, setItems] = useState<ClipboardItem[]>([])
  const [pinned, setPinned] = useState(true)

  const loadItems = useCallback(async () => {
    const fetched = await window.electron.ipcRenderer.invoke('widget:getItems')
    setItems(fetched)
  }, [])

  useEffect(() => {
    loadItems()

    const unsubShown = window.api.onWidgetShown(() => {
      loadItems()
    })

    const unsubPinned = window.api.onWidgetPinnedChanged((value: boolean) => {
      setPinned(value)
    })

    const unsubNewItem = window.api.onNewItem(() => {
      loadItems()
    })

    // Refresh when filter changes (follow mode)
    const onFilterChanged = (): void => { loadItems() }
    window.electron.ipcRenderer.on('widget:filterChanged', onFilterChanged)

    return () => {
      unsubShown()
      unsubPinned()
      unsubNewItem()
      window.electron.ipcRenderer.removeListener('widget:filterChanged', onFilterChanged)
    }
  }, [loadItems])

  const togglePin = useCallback(() => {
    const next = !pinned
    setPinned(next)
    window.api.widgetSetPinned(next)
  }, [pinned])

  const handleClose = useCallback(() => {
    window.api.widgetSetPinned(false)
    window.electron.ipcRenderer.invoke('widget:toggle')
  }, [])

  const handlePaste = useCallback((id: string) => {
    window.electron.ipcRenderer.invoke('widget:pasteItem', id)
  }, [])

  return (
    <div className="surface-panel hairline w-full h-full rounded-[1.25rem] border border-border/70 overflow-hidden flex flex-col shadow-2xl select-none">
      {/* Title bar - draggable */}
      <div
        style={{ WebkitAppRegion: 'drag' } as React.CSSProperties}
        className="surface-subtle flex items-center justify-between px-3 py-2 border-b border-border/50 shrink-0"
      >
        <div className="flex items-center gap-1.5 text-xs font-semibold text-foreground tracking-tight">
          <Clipboard className="w-3.5 h-3.5 text-primary" />
          <span>{t('widget.title')}</span>
        </div>
        <div
          style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}
          className="flex items-center gap-1"
        >
          <button
            onClick={togglePin}
            aria-label="Toggle pin"
            className={cn(
              "p-1 rounded-md hover:bg-black/[0.05] dark:hover:bg-white/[0.08] transition-colors active:scale-95",
              pinned ? "text-primary font-semibold" : "text-muted-foreground/80 hover:text-foreground"
            )}
          >
            <Pin className="w-3.5 h-3.5" />
          </button>
          <button
            onClick={handleClose}
            aria-label="Close widget"
            className="p-1 rounded-md hover:bg-black/[0.05] dark:hover:bg-white/[0.08] text-muted-foreground/80 hover:text-foreground transition-colors active:scale-95"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Items list */}
      <div className="flex-1 overflow-y-auto p-1 space-y-0.5">
        {items.map((item, index) => (
          <button
            key={item.id}
            onClick={() => handlePaste(item.id)}
            className="w-full flex items-center gap-2 px-2.5 py-1.5 rounded-lg hover:bg-black/[0.04] dark:hover:bg-white/[0.06] transition-all duration-150 text-left active:scale-[0.99] group"
          >
            <span className="text-[10px] font-mono text-muted-foreground/70 w-5 shrink-0 tabular-nums">
              ⌥{index + 1}
            </span>
            {item.content_type === 'image' ? (
              <img
                src={item.content.startsWith('/') ? `file://${item.content}` : `data:image/png;base64,${item.content}`}
                alt=""
                className="h-7 w-10 object-cover rounded-md border border-border/60 shrink-0 shadow-2xs"
                loading="lazy"
              />
            ) : null}
            <span className="text-xs truncate flex-1 text-foreground/90 group-hover:text-foreground">
              {item.content_type === 'image'
                ? (item.preview || t('widget.imageFallback'))
                : truncate(item.preview || item.content, 38)}
            </span>
            <ContentTypeIcon type={item.content_type} />
          </button>
        ))}
        {items.length === 0 && (
          <div className="flex items-center justify-center h-full text-xs text-muted-foreground/60">
            {t('widget.empty')}
          </div>
        )}
      </div>
    </div>
  )
}

export default WidgetPanel
