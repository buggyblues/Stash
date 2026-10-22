import { useTranslation } from 'react-i18next'
import { useClipboardStore, LeftFilter } from '../../stores/clipboardStore'
import { cn } from '../../lib/utils'
import { Star, Layers } from 'lucide-react'

export default function Sidebar(): React.JSX.Element {
  const { t } = useTranslation()
  const { leftFilter, setLeftFilter, starredCount } = useClipboardStore()

  const isActive = (f: LeftFilter): boolean => {
    if (f.type !== leftFilter.type) return false
    return true
  }

  return (
    <div className="w-44 shrink-0 border-r flex flex-col py-2 overflow-y-auto bg-muted/10">
      <NavItem
        icon={<Layers className="w-3.5 h-3.5" />}
        label={t('panel.sidebar.all')}
        active={isActive({ type: 'all' })}
        onClick={() => setLeftFilter({ type: 'all' })}
      />
      <NavItem
        icon={<Star className="w-3.5 h-3.5" />}
        label={t('panel.sidebar.starred')}
        count={starredCount}
        active={isActive({ type: 'starred' })}
        onClick={() => setLeftFilter({ type: 'starred' })}
      />
    </div>
  )
}

function NavItem({
  icon,
  label,
  count,
  active,
  onClick
}: {
  icon: React.ReactNode
  label: string
  count?: number
  active: boolean
  onClick: () => void
}): React.JSX.Element {
  return (
    <button
      onClick={onClick}
      className={cn(
        'w-full flex items-center gap-2 px-3 py-1.5 text-xs rounded-md mx-1 transition-colors',
        active
          ? 'bg-accent text-accent-foreground font-medium'
          : 'text-muted-foreground hover:bg-muted/50 hover:text-foreground'
      )}
      style={{ width: 'calc(100% - 8px)' }}
    >
      <span className="shrink-0">{icon}</span>
      <span className="flex-1 text-left truncate">{label}</span>
      {count !== undefined && count > 0 && (
        <span className="text-[10px] text-muted-foreground/60 tabular-nums">{count}</span>
      )}
    </button>
  )
}
