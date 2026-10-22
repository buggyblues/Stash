import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { useClipboardStore } from '../../stores/clipboardStore'
import { cn } from '../../lib/utils'
import { getCachedSourceApps, setCachedSourceApps } from './filterTabsCache'

interface SourceApp {
  name: string
  bundleId: string
  count: number
}

const iconCache = new Map<string, string>()

export default function FilterTabs(): React.JSX.Element {
  const { t } = useTranslation()
  const filterType = useClipboardStore((state) => state.filterType)
  const setFilterType = useClipboardStore((state) => state.setFilterType)
  const sourceAppFilter = useClipboardStore((state) => state.sourceAppFilter)
  const setSourceAppFilter = useClipboardStore((state) => state.setSourceAppFilter)
  const leftFilter = useClipboardStore((state) => state.leftFilter)
  const typeFilterCollapsed = useClipboardStore((state) => state.typeFilterCollapsed)
  const sourceAppFilterCollapsed = useClipboardStore((state) => state.sourceAppFilterCollapsed)
  const itemsRevision = useClipboardStore((state) => state.itemsRevision)

  const tabs = [
    { label: t('panel.filter.all'), value: null },
    { label: t('panel.filter.text'), value: 'text' },
    { label: t('panel.filter.code'), value: 'code' },
    { label: t('panel.filter.url'), value: 'url' },
    { label: t('panel.filter.json'), value: 'json' },
    { label: t('panel.filter.color'), value: 'color' },
    { label: t('panel.filter.image'), value: 'image' }
  ]
  const [sourceApps, setSourceApps] = useState<SourceApp[]>(() => getCachedSourceApps())
  const [appIcons, setAppIcons] = useState<Map<string, string>>(
    () =>
      new Map(
        getCachedSourceApps()
          .filter((app) => app.bundleId && iconCache.has(app.bundleId))
          .map((app) => [app.bundleId, iconCache.get(app.bundleId)!])
      )
  )
  const [typeCounts, setTypeCounts] = useState<Record<string, number>>({})

  useEffect(() => {
    window.api.getSourceApps().then((apps) => {
      setCachedSourceApps(apps)
      setSourceApps(apps)
      for (const app of apps) {
        if (!app.bundleId || iconCache.has(app.bundleId)) {
          if (iconCache.has(app.bundleId)) {
            setAppIcons((prev) => new Map(prev).set(app.bundleId, iconCache.get(app.bundleId)!))
          }
          continue
        }
        window.api.getAppIcon(app.bundleId).then((icon) => {
          if (icon) {
            iconCache.set(app.bundleId, icon)
            setAppIcons((prev) => new Map(prev).set(app.bundleId, icon))
          }
        })
      }
    })
  }, [itemsRevision])

  // Counts depend on data/filter changes, not on a single item's lazy content
  // being hydrated in the renderer.
  useEffect(() => {
    window.api.getContentTypeCounts({
      leftFilter: leftFilter,
      sourceApp: sourceAppFilter || undefined
    }).then(setTypeCounts)
  }, [itemsRevision, leftFilter, sourceAppFilter])

  const showTypeFilter = !typeFilterCollapsed
  const showSourceApps = !sourceAppFilterCollapsed && sourceApps.length > 0

  if (!showTypeFilter && !showSourceApps) return <></>

  return (
    <div className="border-b border-border/50 surface-subtle select-none">
      {showTypeFilter && (
        <div className="no-scrollbar flex items-center gap-1 overflow-x-auto px-2 py-1">
          {tabs.map(({ label, value }) => {
            const isActive = filterType === value
            const count = value !== null ? (typeCounts[value] || 0) : 0
            return (
              <button
                key={label}
                type="button"
                onClick={() => setFilterType(value)}
                className={cn(
                  'shrink-0 flex items-center whitespace-nowrap rounded-full px-2.5 py-0.5 text-[11px] font-medium transition-all duration-150 active:scale-95',
                  isActive
                    ? 'bg-primary text-primary-foreground shadow-[inset_0_1px_0_0_rgba(255,255,255,0.3),0_1px_2px_rgba(0,0,0,0.12)]'
                    : 'border border-black/[0.06] dark:border-white/[0.08] bg-black/[0.03] dark:bg-white/[0.06] text-muted-foreground hover:bg-black/[0.06] dark:hover:bg-white/[0.12] hover:text-foreground'
                )}
              >
                <span>{label}</span>
                {count > 0 && (
                  <span className={cn(
                    'ml-1 rounded-full px-1 text-[9px] tabular-nums font-semibold',
                    isActive ? 'bg-black/15 dark:bg-white/20' : 'bg-black/10 dark:bg-white/10'
                  )}>
                    {count}
                  </span>
                )}
              </button>
            )
          })}
        </div>
      )}

      {showSourceApps && (
        <div className={cn(
          'no-scrollbar flex items-center gap-1 overflow-x-auto px-2 py-1',
          showTypeFilter && 'border-t border-border/40'
        )}>
          <button
            type="button"
            className={cn(
              'inline-flex shrink-0 items-center rounded-full px-2.5 py-0.5 text-[11px] font-medium transition-all duration-150 active:scale-95',
              sourceAppFilter === null
                ? 'bg-primary text-primary-foreground shadow-[inset_0_1px_0_0_rgba(255,255,255,0.3),0_1px_2px_rgba(0,0,0,0.12)]'
                : 'border border-black/[0.06] dark:border-white/[0.08] bg-black/[0.03] dark:bg-white/[0.06] text-muted-foreground hover:bg-black/[0.06] dark:hover:bg-white/[0.12] hover:text-foreground'
            )}
            onClick={() => setSourceAppFilter(null)}
          >
            {t('panel.filter.all')}
          </button>
          {sourceApps.map((app) => {
            const isActive = sourceAppFilter === app.bundleId
            const icon = appIcons.get(app.bundleId)
            return (
              <button
                key={app.bundleId}
                type="button"
                className={cn(
                  'inline-flex shrink-0 items-center gap-1.5 rounded-full pl-1.5 pr-2 py-0.5 text-[11px] font-medium transition-all duration-150 active:scale-95',
                  isActive
                    ? 'bg-primary text-primary-foreground shadow-[inset_0_1px_0_0_rgba(255,255,255,0.3),0_1px_2px_rgba(0,0,0,0.12)]'
                    : 'border border-black/[0.06] dark:border-white/[0.08] bg-black/[0.03] dark:bg-white/[0.06] text-muted-foreground hover:bg-black/[0.06] dark:hover:bg-white/[0.12] hover:text-foreground'
                )}
                onClick={() => setSourceAppFilter(isActive ? null : app.bundleId)}
              >
                {icon ? (
                  <img
                    src={`data:image/png;base64,${icon}`}
                    alt={app.name}
                    title={app.name}
                    className="w-3.5 h-3.5 rounded-sm object-contain shrink-0 shadow-xs"
                  />
                ) : (
                  <span className="max-w-[80px] truncate">{app.name}</span>
                )}
                <span className={cn(
                  'rounded-full px-1 text-[9px] tabular-nums font-semibold',
                  isActive ? 'bg-black/15 dark:bg-white/20' : 'bg-black/10 dark:bg-white/10'
                )}>{app.count}</span>
              </button>
            )
          })}
        </div>
      )}
    </div>
  )
}
