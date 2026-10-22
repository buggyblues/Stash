import { memo, useState, useCallback, useEffect, useRef } from 'react'

import { useTranslation } from 'react-i18next'
import SearchBar from './SearchBar'
import ClipboardList from './ClipboardList'
import ClipboardCardList from './ClipboardCardList'
import FilterTabs from './FilterTabs'
import TagBar from './TagBar'
import TagPicker from './TagPicker'
import PreviewPanel from '../Preview/PreviewPanel'
import QuickEdit from './QuickEdit'

import TemplateList from '../Templates/TemplateList'
import { useKeyboard } from '../../hooks/useKeyboard'
import { useQueueToast } from '../../hooks/useQueueToast'
import { useSearch } from '../../hooks/useSearch'
import { useClipboardStore } from '../../stores/clipboardStore'
import { useSettingsStore } from '../../stores/settingsStore'
import { useShallow } from 'zustand/react/shallow'
import { matchShortcut } from '../../utils/shortcut'
import appIcon from '../../assets/icon.png'
import { Settings, PanelRightOpen, HelpCircle, ListOrdered, X } from 'lucide-react'
import { Button } from '../ui/button'
import { cn } from '../../lib/utils'

export type PanelView = 'clipboard' | 'templates'

function PanelWindow(): React.JSX.Element {
  const { t } = useTranslation()
  const [view, setView] = useState<PanelView>('clipboard')
  const layoutMode = useSettingsStore((s) => s.layoutMode)
  useKeyboard()
  useQueueToast()
  const items = useSearch()
  const { selectedIndex, pasteItem, previewCollapsed, togglePreview, filtersCollapsed, toggleFilters, isQueueActive, sequenceQueue, clearQueue, tagBarCollapsed, toggleTagBar, typeFilterCollapsed, toggleTypeFilter, sourceAppFilterCollapsed, toggleSourceAppFilter } = useClipboardStore()
  const loadItemContent = useClipboardStore((state) => state.loadItemContent)
  const {
    toggleFilterShortcut,
    togglePreviewShortcut,
    openTagShortcut,
    openSettingsShortcut,
  } = useSettingsStore(useShallow((state) => ({
    toggleFilterShortcut: state.toggleFilterShortcut,
    togglePreviewShortcut: state.togglePreviewShortcut,
    openTagShortcut: state.openTagShortcut,
    openSettingsShortcut: state.openSettingsShortcut,
  })))
  const selectedItem = items[selectedIndex] || null
  const [editingItem, setEditingItem] = useState<string | null>(null)
  const [tagPickerItemId, setTagPickerItemId] = useState<string | null>(null)
  const tagPickerAnchorRef = useRef<HTMLDivElement>(null)
  // 右侧预览 debounce：hover 稳定 150ms 后才显示
  const [previewItemId, setPreviewItemId] = useState<string | null>(null)
  const previewItem = previewItemId
    ? items.find((item) => item.id === previewItemId) || null
    : null
  const previewTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const handleDoubleClick = useCallback((itemId: string) => {
    void loadItemContent(itemId).then((content) => {
      if (content !== null) setEditingItem(itemId)
    })
  }, [loadItemContent])

  const handleEditSave = useCallback(
    (content: string) => {
      navigator.clipboard.writeText(content)
      setEditingItem(null)
      if (selectedItem) {
        pasteItem(selectedItem.id)
      }
    },
    [selectedItem, pasteItem]
  )

  useEffect(() => {
    if (previewTimerRef.current) clearTimeout(previewTimerRef.current)
    if (!selectedItem) {
      setPreviewItemId(null)
      return
    }
    previewTimerRef.current = setTimeout(() => {
      setPreviewItemId(selectedItem.id)
    }, 150)
    return () => {
      if (previewTimerRef.current) clearTimeout(previewTimerRef.current)
    }
  }, [selectedItem?.id])

  const openTagPicker = useCallback((itemId: string) => {
    setTagPickerItemId(itemId)
  }, [])

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent): void => {
      if (matchShortcut(e, openSettingsShortcut)) {
        e.preventDefault()
        window.api.openSettingsWindow('settings')
        return
      }
      if (matchShortcut(e, toggleFilterShortcut)) {
        e.preventDefault()
        toggleFilters()
        return
      }
      if (matchShortcut(e, togglePreviewShortcut)) {
        e.preventDefault()
        togglePreview()
        return
      }
      if (matchShortcut(e, openTagShortcut)) {
        const target = document.activeElement?.tagName
        if (target === 'INPUT' || target === 'TEXTAREA') return
        if (tagPickerItemId) return
        if (selectedItem) {
          e.preventDefault()
          setTagPickerItemId(selectedItem.id)
        }
      }
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [selectedItem, tagPickerItemId, togglePreview, toggleFilters, toggleFilterShortcut, togglePreviewShortcut, openTagShortcut, openSettingsShortcut])

  const containerClass =
    'surface-panel hairline flex h-full w-full flex-col overflow-hidden rounded-[1.25rem] border border-border/70 select-none'

  return (
    <div className={containerClass}>
      <div
        className="surface-subtle flex h-12 shrink-0 items-center gap-2.5 border-b border-border/50 px-3"
        style={{ WebkitAppRegion: 'drag' } as React.CSSProperties}
      >
        <div className="shrink-0 flex items-center">
          <img src={appIcon} alt="Stash" className="h-6 w-6 rounded-md drop-shadow-sm" />
        </div>

        <div
          className="mac-segmented-track flex shrink-0 items-center gap-0.5 rounded-lg p-0.5"
          style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}
        >
          <TabButton
            label={t('panel.tabs.clipboard')}
            active={view === 'clipboard'}
            onClick={() => setView('clipboard')}
          />
        </div>

        <div className="min-w-0 flex-1" style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}>
          <SearchBar view={view} />
        </div>
        <div className="ml-0.5 flex shrink-0 items-center gap-1" style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}>
          {view === 'clipboard' && layoutMode !== 'side' && (
            <div className="flex items-center gap-1 mr-0.5" style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}>
              {[
                { collapsed: tagBarCollapsed, toggle: toggleTagBar, label: '1' },
                { collapsed: typeFilterCollapsed, toggle: toggleTypeFilter, label: '2' },
                { collapsed: sourceAppFilterCollapsed, toggle: toggleSourceAppFilter, label: '3' },
              ].map(({ collapsed, toggle, label }) => (
                <button
                  key={label}
                  onClick={toggle}
                  aria-label={`Toggle filter ${label}`}
                  className={cn(
                    'flex h-5 w-5 items-center justify-center rounded-md text-[10px] font-semibold transition-all duration-150 active:scale-95',
                    collapsed
                      ? 'bg-black/[0.04] dark:bg-white/[0.08] text-muted-foreground/70 hover:bg-black/[0.08] dark:hover:bg-white/[0.14] hover:text-foreground'
                      : 'bg-primary text-primary-foreground shadow-[inset_0_1px_0_rgba(255,255,255,0.35),0_1px_2px_rgba(0,0,0,0.15)]'
                  )}
                >
                  {label}
                </button>
              ))}
            </div>
          )}
          <button
            onClick={() => window.api.openSettingsWindow('onboarding')}
            aria-label={t('panel.help.tooltip')}
            className="flex h-7 w-7 items-center justify-center rounded-lg border border-transparent bg-transparent text-muted-foreground/80 hover:border-border/50 hover:bg-black/[0.04] dark:hover:bg-white/[0.08] hover:text-foreground transition-all duration-150 active:scale-95"
            title={t('panel.help.tooltip')}
          >
            <HelpCircle className="w-3.5 h-3.5" />
          </button>
          <button
            onClick={() => window.api.openSettingsWindow('settings')}
            aria-label={t('panel.settings.tooltip')}
            className="flex h-7 w-7 items-center justify-center rounded-lg border border-transparent bg-transparent text-muted-foreground/80 hover:border-border/50 hover:bg-black/[0.04] dark:hover:bg-white/[0.08] hover:text-foreground transition-all duration-150 active:scale-95"
            title={t('panel.settings.tooltip')}
          >
            <Settings className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {view === 'clipboard' ? (
        layoutMode === 'bottom' ? (
          /* ── Bottom slide-out: horizontal card carousel ── */
          <div className="flex flex-1 min-h-0 flex-col">
            {!filtersCollapsed && (
              <>
                <TagBar />
                <FilterTabs />
              </>
            )}
            <div className="relative flex flex-1 min-h-0">
              <ClipboardCardList onDoubleClick={handleDoubleClick} onOpenTagPicker={openTagPicker} />
              {tagPickerItemId && (
                <div className="absolute left-3 top-3 z-50">
                  <TagPicker
                    itemId={tagPickerItemId}
                    onClose={() => setTagPickerItemId(null)}
                  />
                </div>
              )}
            </div>
          </div>
        ) : layoutMode === 'side' ? (
          /* ── Side slide-out: list + preview below ── */
          <div className="flex flex-1 min-h-0 flex-col">
            <div className="flex flex-col flex-1 min-h-0 min-w-0">
              {!filtersCollapsed && (
                <>
                  <TagBar />
                  <FilterTabs />
                </>
              )}
              <div className="flex flex-1 flex-col min-h-0 relative">
                <div
                  className="relative flex min-h-0 flex-1 flex-col"
                  ref={tagPickerAnchorRef}
                >
                  <ClipboardList onDoubleClick={handleDoubleClick} onOpenTagPicker={openTagPicker} />
                  {tagPickerItemId && (
                    <div className="absolute left-2.5 top-8 z-50">
                      <TagPicker
                        itemId={tagPickerItemId}
                        onClose={() => setTagPickerItemId(null)}
                      />
                    </div>
                  )}
                </div>
                {!previewCollapsed && (editingItem && selectedItem ? (
                  <div className="flex shrink-0 max-h-[40%] flex-col overflow-hidden border-t border-border/50">
                    <QuickEdit
                      content={selectedItem.content}
                      onSave={handleEditSave}
                      onCancel={() => setEditingItem(null)}
                    />
                  </div>
                ) : previewItem ? (
                  <div className="flex shrink-0 max-h-[40%] flex-col overflow-hidden border-t border-border/50">
                    <PreviewPanel item={previewItem} layout="bottom" />
                  </div>
                ) : null)}
                {previewCollapsed && (previewItem || selectedItem) && (
                  <button
                    onClick={togglePreview}
                    aria-label={t('panel.preview.expand')}
                    className="surface-subtle shrink-0 flex h-7 items-center justify-center border-t border-border/50 text-muted-foreground transition-colors hover:bg-muted/60 hover:text-foreground"
                    title={t('panel.preview.expand')}
                  >
                    <PanelRightOpen className="w-3.5 h-3.5 rotate-90" />
                  </button>
                )}
              </div>
            </div>
          </div>
        ) : (
          /* ── Center: list + preview on right ── */
          <div className="flex flex-1 min-h-0">
            <div className="flex flex-col flex-1 min-h-0 min-w-0">
              {!filtersCollapsed && (
                <>
                  <TagBar />
                  <FilterTabs />
                </>
              )}
              <div className="flex-1 flex min-h-0 overflow-hidden relative">
                <div
                  className={cn(
                    'relative flex min-h-0 flex-col',
                    !previewCollapsed && (previewItem || (editingItem && selectedItem)) ? 'w-[56%] border-r border-border/50' : 'flex-1'
                  )}
                  ref={tagPickerAnchorRef}
                >
                  <ClipboardList onDoubleClick={handleDoubleClick} onOpenTagPicker={openTagPicker} />
                  {tagPickerItemId && (
                    <div className="absolute left-2.5 top-8 z-50">
                      <TagPicker
                        itemId={tagPickerItemId}
                        onClose={() => setTagPickerItemId(null)}
                      />
                    </div>
                  )}
                </div>
                {!previewCollapsed && (editingItem && selectedItem ? (
                  <QuickEdit
                    content={selectedItem.content}
                    onSave={handleEditSave}
                    onCancel={() => setEditingItem(null)}
                  />
                ) : previewItem ? (
                  <PreviewPanel item={previewItem} />
                ) : null)}
                {previewCollapsed && (previewItem || selectedItem) && (
                  <button
                    onClick={togglePreview}
                    aria-label={t('panel.preview.expand')}
                    className="surface-subtle shrink-0 flex w-7 items-center justify-center border-l border-border/50 text-muted-foreground transition-colors hover:bg-muted/60 hover:text-foreground"
                    title={t('panel.preview.expand')}
                  >
                    <PanelRightOpen className="w-3.5 h-3.5" />
                  </button>
                )}
              </div>
            </div>
          </div>
        )
      ) : (
        <TemplateList />
      )}

      {/* Queue status bar */}
      {isQueueActive && (
        <div className="flex items-center gap-2 border-t border-primary/25 bg-primary/12 backdrop-blur-md px-3 py-1.5 animate-in slide-in-from-bottom-1">
          <ListOrdered className="w-3.5 h-3.5 text-primary shrink-0" />
          <span className="flex-1 text-xs font-semibold text-primary">
            {t('panel.queue.active', { count: sequenceQueue.length })}
          </span>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => {
              clearQueue()
              window.api.queueClear()
            }}
            className="h-6 rounded-md px-2 text-xs text-destructive hover:bg-destructive/15 hover:text-destructive"
          >
            <X className="w-3 h-3 mr-1" />
            {t('panel.queue.abandon')}
          </Button>
        </div>
      )}
    </div>
  )
}

export default memo(PanelWindow)

function TabButton({
  label,
  active,
  onClick
}: {
  label: string
  active: boolean
  onClick: () => void
}): React.JSX.Element {
  return (
    <button
      onClick={onClick}
      className={cn(
        'rounded-md px-2.5 py-1 text-xs font-medium transition-all duration-150',
        active
          ? 'mac-segmented-active'
          : 'text-muted-foreground hover:text-foreground'
      )}
    >
      {label}
    </button>
  )
}
