import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { useClipboardStore } from '../../stores/clipboardStore'
import { Badge } from '../ui/badge'
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
    <div className="border-b border-border/60 surface-subtle">
      {showTypeFilter && (
        <div className="no-scrollbar flex items-center gap-1.5 overflow-x-auto px-2.5 py-1.5">
          {tabs.map(({ label, value }) => {
            const isActive = filterType === value
            const count = value !== null ? (typeCounts[value] || 0) : 0
            return (
              <Badge
                key={label}
                variant={isActive ? 'default' : 'secondary'}
                className={cn(
                  'cursor-pointer whitespace-nowrap border px-2.5 py-1 text-[11px]',
                  !isActive &&
                    'border-transparent bg-transparent text-muted-foreground hover:border-border/60 hover:bg-background/65 hover:text-foreground'
                )}
                onClick={() => setFilterType(value)}
              >
                {label}
                {count > 0 && (
                  <span className={cn(
                    'ml-1 text-[10px] tabular-nums',
                    isActive ? 'opacity-80' : 'opacity-50'
                  )}>
                    {count}
                  </span>
                )}
              </Badge>
            )
          })}

        </div>
      )}

      {showSourceApps && (
        <div className={cn(
          'no-scrollbar flex items-center gap-1.5 overflow-x-auto px-2.5 py-1.5',
          showTypeFilter && 'border-t border-border/50'
        )}>
          <button
            className={cn(
              'inline-flex shrink-0 items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold transition-colors',
              sourceAppFilter === null
                ? 'bg-primary text-primary-foreground'
                : 'border-transparent bg-transparent text-muted-foreground hover:border-border/60 hover:bg-background/65 hover:text-foreground'
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
                className={cn(
                  'inline-flex shrink-0 items-center gap-1.5 rounded-full border pl-1.5 pr-2.5 py-1 text-[11px] font-semibold transition-colors',
                  isActive
                    ? 'bg-primary text-primary-foreground'
                    : 'border-transparent bg-transparent text-muted-foreground hover:border-border/60 hover:bg-background/65 hover:text-foreground'
                )}
                onClick={() => setSourceAppFilter(isActive ? null : app.bundleId)}
              >
                {icon ? (
                  <img
                    src={`data:image/png;base64,${icon}`}
                    alt={app.name}
                    title={app.name}
                    className="w-4 h-4 rounded-sm object-contain shrink-0"
                  />
                ) : (
                  <span className="max-w-[90px] truncate">{app.name}</span>
                )}
                <span className="text-[10px] tabular-nums opacity-70">{app.count}</span>
              </button>
            )
          })}
        </div>
      )}
    </div>
  )
}
