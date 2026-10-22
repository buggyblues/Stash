import { memo, useState, useCallback, useEffect, useRef } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useSettingsStore, ThemeMode, LanguageMode, LayoutMode } from '../../stores/settingsStore'
import { useTagStore, TagWithCount } from '../../stores/tagStore'
import { useShallow } from 'zustand/react/shallow'
import { Switch } from '../ui/switch'
import { AppLogo } from '../ui/app-logo'
import { Input } from '../ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../ui/select'
import { Button } from '../ui/button'
import { showToast } from '../../utils/toast'
import { cn } from '../../lib/utils'
import { formatShortcut, eventToShortcut } from '../../utils/shortcut'
import {
  MAX_ITEMS_CUSTOM_MIN,
  MAX_ITEMS_PRESETS,
  MAX_ITEMS_UNLIMITED,
  isPresetMaxItems,
} from '../../../../shared/max-items'
import {
  Settings,
  Keyboard,
  Cloud,
  Lock,
  Palette,
  Info,
  Moon,
  Sun,
  Monitor,
  Trash2,
  RefreshCw,
  Tag,
  Pencil,
  GitMerge,
  AlertTriangle,
  LayoutGrid,
  Download,
  CheckCircle2,
  RotateCcw,
  Pipette,
} from 'lucide-react'

type SettingsSection =
  | 'general'
  | 'shortcuts'
  | 'widget'
  | 'sync'
  | 'privacy'
  | 'theme'
  | 'tags'
  | 'about'

interface Props {
  onClose: () => void
}

function SettingsPage({ onClose }: Props): React.JSX.Element {
  const [activeSection, setActiveSection] = useState<SettingsSection>('general')
  const { t } = useTranslation()

  const sections: { id: SettingsSection; label: string; icon: React.ElementType }[] = [
    { id: 'general', label: t('settings.nav.general'), icon: Settings },
    { id: 'shortcuts', label: t('settings.nav.shortcuts'), icon: Keyboard },
    { id: 'widget', label: t('settings.nav.widget'), icon: LayoutGrid },
    { id: 'sync', label: t('settings.nav.sync'), icon: Cloud },
    { id: 'privacy', label: t('settings.nav.privacy'), icon: Lock },
    { id: 'theme', label: t('settings.nav.theme'), icon: Palette },
    { id: 'tags', label: t('settings.nav.tags'), icon: Tag },
    { id: 'about', label: t('settings.nav.about'), icon: Info },
  ]

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.98, y: 12 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      transition={{ duration: 0.25, ease: 'easeOut' }}
      className="surface-panel hairline flex flex-col h-full text-foreground rounded-[1.25rem] border border-border/70 overflow-hidden shadow-2xl select-none"
    >
      {/* Header */}
      <div
        className="surface-subtle flex h-12 shrink-0 items-center justify-between border-b border-border/50 px-5"
        style={{ WebkitAppRegion: 'drag' } as React.CSSProperties}
      >
        <div className="flex items-center gap-2.5">
          <div className="flex h-6 w-6 items-center justify-center rounded-lg bg-black/[0.04] dark:bg-white/[0.08] text-muted-foreground">
            <Settings className="w-3.5 h-3.5" />
          </div>
          <h1 className="text-xs font-semibold text-foreground tracking-tight">{t('settings.title')}</h1>
        </div>
        <div style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}>
          <Button
            variant="secondary"
            size="sm"
            onClick={onClose}
            className="h-6 px-2.5 text-[11px]"
          >
            {t('common.close')}
          </Button>
        </div>
      </div>

      <div className="flex flex-1 min-h-0">
        {/* Left nav */}
        <div className="w-48 shrink-0 surface-subtle border-r border-border/50 py-3 px-2 flex flex-col gap-0.5">
          {sections.map((section) => {
            const isActive = activeSection === section.id
            return (
              <button
                key={section.id}
                onClick={() => setActiveSection(section.id)}
                className={cn(
                  'w-full text-left px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all duration-150 flex items-center gap-2.5 my-0.5 active:scale-[0.98]',
                  isActive
                    ? 'bg-primary text-primary-foreground shadow-[inset_0_1px_0_rgba(255,255,255,0.3),0_1px_2px_rgba(0,0,0,0.12)]'
                    : 'text-muted-foreground hover:bg-black/[0.04] dark:hover:bg-white/[0.06] hover:text-foreground'
                )}
              >
                <div className={cn(
                  'flex items-center justify-center w-5 h-5 rounded-md transition-colors',
                  isActive ? 'text-primary-foreground' : 'text-muted-foreground/80'
                )}>
                  <section.icon className="w-3.5 h-3.5" />
                </div>
                <span className="truncate">{section.label}</span>
              </button>
            )
          })}
        </div>

        {/* Right content */}
        <div className="flex-1 overflow-y-auto px-7 py-5">
          <SectionContent section={activeSection} />
        </div>
      </div>
    </motion.div>
  )
}

function SectionContent({ section }: { section: SettingsSection }): React.JSX.Element {
  switch (section) {
    case 'general':
      return <GeneralSection />
    case 'shortcuts':
      return <ShortcutsSection />
    case 'widget':
      return <WidgetSection />
    case 'sync':
      return <SyncSection />
    case 'privacy':
      return <PrivacySection />
    case 'theme':
      return <ThemeSection />
    case 'tags':
      return <TagManagementSection />
    case 'about':
      return <AboutSection />
    default:
      return <GeneralSection />
  }
}

function SectionTitle({ title }: { title: string }): React.JSX.Element {
  return (
    <h2 className="text-[11px] font-semibold text-muted-foreground/80 uppercase tracking-wider mb-2 px-1">
      {title}
    </h2>
  )
}

function SettingsItem({
  label,
  description,
  children,
}: {
  label: string
  description?: string
  children: React.ReactNode
}): React.JSX.Element {
  return (
    <div className="flex items-center justify-between py-2.5 px-3.5 transition-colors">
      <div className="flex-1 min-w-0 mr-4">
        <p className="text-xs font-medium text-foreground">{label}</p>
        {description && <p className="text-[11px] text-muted-foreground/75 mt-0.5 leading-normal">{description}</p>}
      </div>
      <div className="shrink-0">{children}</div>
    </div>
  )
}

function GeneralSection(): React.JSX.Element {
  const { t } = useTranslation()
  const {
    launchAtLogin,
    setLaunchAtLogin,
    historyRetention,
    setHistoryRetention,
    maxItems,
    setMaxItems,
    language,
    setLanguage,
    layoutMode,
    setLayoutMode,
  } = useSettingsStore(useShallow((state) => ({
    launchAtLogin: state.launchAtLogin,
    setLaunchAtLogin: state.setLaunchAtLogin,
    historyRetention: state.historyRetention,
    setHistoryRetention: state.setHistoryRetention,
    maxItems: state.maxItems,
    setMaxItems: state.setMaxItems,
    language: state.language,
    setLanguage: state.setLanguage,
    layoutMode: state.layoutMode,
    setLayoutMode: state.setLayoutMode,
  })))
  const [isCustomMaxItemsSelected, setIsCustomMaxItemsSelected] = useState(
    maxItems > 0 && !isPresetMaxItems(maxItems)
  )
  const [customMaxItems, setCustomMaxItems] = useState(
    maxItems > 0 && !isPresetMaxItems(maxItems) ? String(maxItems) : String(MAX_ITEMS_CUSTOM_MIN)
  )

  useEffect(() => {
    if (maxItems === MAX_ITEMS_UNLIMITED) {
      setIsCustomMaxItemsSelected(false)
      return
    }

    if (isPresetMaxItems(maxItems)) {
      setIsCustomMaxItemsSelected(false)
      return
    }

    setIsCustomMaxItemsSelected(true)
    setCustomMaxItems(String(maxItems))
  }, [maxItems])

  const parsedCustomMaxItems = Number(customMaxItems)
  const canSaveCustomMaxItems =
    /^\d+$/.test(customMaxItems.trim()) && parsedCustomMaxItems >= MAX_ITEMS_CUSTOM_MIN
  const maxItemsSelectValue = isCustomMaxItemsSelected
    ? 'custom'
    : maxItems === MAX_ITEMS_UNLIMITED
      ? 'unlimited'
      : String(maxItems)

  const handleMaxItemsChange = (value: string): void => {
    if (value === 'custom') {
      setIsCustomMaxItemsSelected(true)
      setCustomMaxItems(
        String(Math.max(maxItems || MAX_ITEMS_CUSTOM_MIN, MAX_ITEMS_CUSTOM_MIN))
      )
      return
    }

    setIsCustomMaxItemsSelected(false)

    if (value === 'unlimited') {
      setMaxItems(MAX_ITEMS_UNLIMITED)
      return
    }

    setMaxItems(Number(value))
  }

  const saveCustomMaxItems = (): void => {
    if (!canSaveCustomMaxItems) return
    setMaxItems(parsedCustomMaxItems)
    showToast(t('settings.general.maxItems.saved'))
  }

  return (
    <div>
      <SectionTitle title={t('settings.general.title')} />
      <div className="mac-group-card divide-y divide-border/40 overflow-hidden mb-6">
        <SettingsItem
          label={t('settings.general.language')}
          description={t('settings.general.language.desc')}
        >
          <Select value={language} onValueChange={(v) => setLanguage(v as LanguageMode)}>
            <SelectTrigger className="w-[150px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="auto">{t('settings.general.language.auto')}</SelectItem>
              <SelectItem value="zh-CN">{t('settings.general.language.zhCN')}</SelectItem>
              <SelectItem value="en">{t('settings.general.language.en')}</SelectItem>
              <SelectItem value="zh-TW">{t('settings.general.language.zhTW')}</SelectItem>
            </SelectContent>
          </Select>
        </SettingsItem>

        <SettingsItem
          label={t('settings.general.layoutMode')}
          description={t('settings.general.layoutMode.desc')}
        >
          <Select value={layoutMode} onValueChange={(v) => setLayoutMode(v as LayoutMode)}>
            <SelectTrigger className="w-[150px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="center">{t('settings.general.layoutMode.center')}</SelectItem>
              <SelectItem value="side">{t('settings.general.layoutMode.side')}</SelectItem>
              <SelectItem value="bottom">{t('settings.general.layoutMode.bottom')}</SelectItem>
            </SelectContent>
          </Select>
        </SettingsItem>

        <SettingsItem
          label={t('settings.general.launchAtLogin')}
          description={t('settings.general.launchAtLogin.desc')}
        >
          <Switch
            checked={launchAtLogin}
            onCheckedChange={(v) => {
              setLaunchAtLogin(v)
              window.api.setLaunchAtLogin?.(v)
            }}
          />
        </SettingsItem>

        <SettingsItem
          label={t('settings.general.historyRetention')}
          description={t('settings.general.historyRetention.desc')}
        >
          <Select
            value={String(historyRetention)}
            onValueChange={(v) => setHistoryRetention(Number(v))}
          >
            <SelectTrigger className="w-[120px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="1">{t('settings.general.retention.1day')}</SelectItem>
              <SelectItem value="7">{t('settings.general.retention.7days')}</SelectItem>
              <SelectItem value="30">{t('settings.general.retention.30days')}</SelectItem>
              <SelectItem value="0">{t('settings.general.retention.forever')}</SelectItem>
            </SelectContent>
          </Select>
        </SettingsItem>

        <SettingsItem
          label={t('settings.general.maxItems')}
          description={t('settings.general.maxItems.desc')}
        >
          <div className="flex flex-col items-end gap-2">
            <Select value={maxItemsSelectValue} onValueChange={handleMaxItemsChange}>
              <SelectTrigger className="w-[140px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {MAX_ITEMS_PRESETS.map((value) => (
                  <SelectItem key={value} value={String(value)}>
                    {value}
                  </SelectItem>
                ))}
                <SelectItem value="custom">{t('settings.general.maxItems.custom')}</SelectItem>
                <SelectItem value="unlimited">
                  {t('settings.general.maxItems.unlimited')}
                </SelectItem>
              </SelectContent>
            </Select>
            {isCustomMaxItemsSelected && (
              <div className="flex flex-col items-end gap-2">
                <div className="flex items-center gap-2">
                  <Input
                    type="number"
                    min={MAX_ITEMS_CUSTOM_MIN}
                    step={1}
                    inputMode="numeric"
                    value={customMaxItems}
                    onChange={(e) => setCustomMaxItems(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') saveCustomMaxItems()
                    }}
                    placeholder={t('settings.general.maxItems.customPlaceholder')}
                    className="w-28 text-right font-mono"
                  />
                  <Button
                    size="sm"
                    variant="secondary"
                    onClick={saveCustomMaxItems}
                    disabled={!canSaveCustomMaxItems}
                  >
                    {t('common.save')}
                  </Button>
                </div>
                <p className="text-[10px] text-muted-foreground">
                  {t('settings.general.maxItems.customHint', {
                    min: MAX_ITEMS_CUSTOM_MIN,
                  })}
                </p>
              </div>
            )}
          </div>
        </SettingsItem>
      </div>
    </div>
  )
}

function ShortcutBadge({ shortcut }: { shortcut: string }): React.JSX.Element {
  return (
    <div className="inline-flex items-center justify-center px-2.5 py-1 rounded-md text-xs font-mono font-medium border border-border/70 bg-card/80 dark:bg-card/40 backdrop-blur-sm shadow-[inset_0_1px_0_rgba(255,255,255,0.7),0_1px_2px_rgba(0,0,0,0.05)] text-foreground">
      {formatShortcut(shortcut)}
    </div>
  )
}

function ShortcutRecorder({
  value,
  onChange,
}: {
  value: string
  onChange: (shortcut: string) => void
}): React.JSX.Element {
  const { t } = useTranslation()
  const [recording, setRecording] = useState(false)
  const ref = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    if (!recording) return
    const handler = (e: KeyboardEvent): void => {
      e.preventDefault()
      e.stopPropagation()
      const shortcut = eventToShortcut(e)
      if (shortcut) {
        onChange(shortcut)
        setRecording(false)
      }
    }
    const blur = (): void => setRecording(false)
    window.addEventListener('keydown', handler, true)
    window.addEventListener('blur', blur)
    return () => {
      window.removeEventListener('keydown', handler, true)
      window.removeEventListener('blur', blur)
    }
  }, [recording, onChange])

  return (
    <button
      ref={ref}
      onClick={() => setRecording(true)}
      className={cn(
        'px-2.5 py-1 rounded-md text-xs font-mono font-medium border transition-all duration-150 min-w-[76px] text-center active:scale-95',
        recording
          ? 'border-primary bg-primary/15 text-primary ring-2 ring-primary/25 animate-pulse'
          : 'border-border/70 bg-card/80 dark:bg-card/40 backdrop-blur-sm hover:border-primary/60 text-foreground shadow-[inset_0_1px_0_rgba(255,255,255,0.7),0_1px_2px_rgba(0,0,0,0.05)]'
      )}
    >
      {recording ? t('settings.shortcuts.recording') : formatShortcut(value)}
    </button>
  )
}

function ShortcutsSection(): React.JSX.Element {
  const { t } = useTranslation()
  const {
    customShortcut,
    sequencePasteShortcut,
    batchPasteShortcut,
    batchPasteSeparator,
    setBatchPasteSeparator,
    toggleFilterShortcut,
    setToggleFilterShortcut,
    togglePreviewShortcut,
    setTogglePreviewShortcut,
    openTagShortcut,
    setOpenTagShortcut,
    openSettingsShortcut,
    setOpenSettingsShortcut,
    cycleLayoutShortcut,
    setCycleLayoutShortcut,
  } = useSettingsStore(useShallow((state) => ({
    customShortcut: state.customShortcut,
    sequencePasteShortcut: state.sequencePasteShortcut,
    batchPasteShortcut: state.batchPasteShortcut,
    batchPasteSeparator: state.batchPasteSeparator,
    setBatchPasteSeparator: state.setBatchPasteSeparator,
    toggleFilterShortcut: state.toggleFilterShortcut,
    setToggleFilterShortcut: state.setToggleFilterShortcut,
    togglePreviewShortcut: state.togglePreviewShortcut,
    setTogglePreviewShortcut: state.setTogglePreviewShortcut,
    openTagShortcut: state.openTagShortcut,
    setOpenTagShortcut: state.setOpenTagShortcut,
    openSettingsShortcut: state.openSettingsShortcut,
    setOpenSettingsShortcut: state.setOpenSettingsShortcut,
    cycleLayoutShortcut: state.cycleLayoutShortcut,
    setCycleLayoutShortcut: state.setCycleLayoutShortcut,
  })))

  const separatorOptions = [
    { value: '\n', label: t('settings.shortcuts.separator.newline') },
    { value: '\t', label: t('settings.shortcuts.separator.tab') },
    { value: ', ', label: t('settings.shortcuts.separator.comma') },
    { value: ' ', label: t('settings.shortcuts.separator.space') },
  ]

  return (
    <div>
      <SectionTitle title={t('settings.shortcuts.title')} />
      <div className="mac-group-card divide-y divide-border/40 overflow-hidden mb-3">
        <SettingsItem
          label={t('settings.shortcuts.showPanel')}
          description={t('settings.shortcuts.showPanel.desc')}
        >
          <ShortcutBadge shortcut={customShortcut} />
        </SettingsItem>

        <SettingsItem
          label={t('settings.shortcuts.sequencePaste')}
          description={t('settings.shortcuts.sequencePaste.desc')}
        >
          <ShortcutBadge shortcut={sequencePasteShortcut} />
        </SettingsItem>

        <SettingsItem
          label={t('settings.shortcuts.batchPaste')}
          description={t('settings.shortcuts.batchPaste.desc')}
        >
          <ShortcutBadge shortcut={batchPasteShortcut} />
        </SettingsItem>

        <SettingsItem
          label={t('settings.shortcuts.addToQueue')}
          description={t('settings.shortcuts.addToQueue.desc')}
        >
          <ShortcutBadge shortcut="Space" />
        </SettingsItem>

        <SettingsItem
          label={t('settings.shortcuts.toggleFilter')}
          description={t('settings.shortcuts.toggleFilter.desc')}
        >
          <ShortcutRecorder value={toggleFilterShortcut} onChange={setToggleFilterShortcut} />
        </SettingsItem>

        <SettingsItem
          label={t('settings.shortcuts.togglePreview')}
          description={t('settings.shortcuts.togglePreview.desc')}
        >
          <ShortcutRecorder value={togglePreviewShortcut} onChange={setTogglePreviewShortcut} />
        </SettingsItem>

        <SettingsItem
          label={t('settings.shortcuts.openTag')}
          description={t('settings.shortcuts.openTag.desc')}
        >
          <ShortcutRecorder value={openTagShortcut} onChange={setOpenTagShortcut} />
        </SettingsItem>

        <SettingsItem
          label={t('settings.shortcuts.openSettings')}
          description={t('settings.shortcuts.openSettings.desc')}
        >
          <ShortcutRecorder value={openSettingsShortcut} onChange={setOpenSettingsShortcut} />
        </SettingsItem>

        <SettingsItem
          label={t('settings.shortcuts.cycleLayout')}
          description={t('settings.shortcuts.cycleLayout.desc')}
        >
          <ShortcutRecorder value={cycleLayoutShortcut} onChange={(v) => {
            setCycleLayoutShortcut(v)
            window.api.updateShortcuts({ cycleLayout: v })
          }} />
        </SettingsItem>

        <SettingsItem
          label={t('settings.shortcuts.batchSeparator')}
          description={t('settings.shortcuts.batchSeparator.desc')}
        >
          <Select
            value={batchPasteSeparator}
            onValueChange={(v) => {
              setBatchPasteSeparator(v)
              window.api.queueSetSeparator(v)
            }}
          >
            <SelectTrigger className="w-[100px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {separatorOptions.map((opt) => (
                <SelectItem key={opt.value} value={opt.value}>
                  {opt.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </SettingsItem>
      </div>
      <p className="text-[11px] text-muted-foreground px-1">{t('settings.shortcuts.hint')}</p>
    </div>
  )
}

function SyncSection(): React.JSX.Element {
  const { t } = useTranslation()
  const { iCloudSync, setICloudSync } = useSettingsStore(useShallow((state) => ({
    iCloudSync: state.iCloudSync,
    setICloudSync: state.setICloudSync,
  })))
  const [syncing, setSyncing] = useState(false)

  const handleSyncNow = useCallback(async () => {
    setSyncing(true)
    try {
      await window.api.syncNow?.()
    } catch {
      // ignore
    }
    setTimeout(() => setSyncing(false), 1500)
  }, [])

  return (
    <div>
      <SectionTitle title={t('settings.sync.title')} />
      <div className="mac-group-card divide-y divide-border/40 overflow-hidden mb-6">
        <SettingsItem label={t('settings.sync.enable')} description={t('settings.sync.enable.desc')}>
          <Switch checked={iCloudSync} onCheckedChange={setICloudSync} />
        </SettingsItem>

        <SettingsItem label={t('settings.sync.now')} description={t('settings.sync.now.desc')}>
          <Button
            variant="outline"
            size="sm"
            onClick={handleSyncNow}
            disabled={!iCloudSync || syncing}
          >
            {syncing ? (
              <>
                <RefreshCw className="w-3 h-3 mr-1.5 animate-spin" />
                {t('settings.sync.syncing')}
              </>
            ) : (
              t('settings.sync.syncButton')
            )}
          </Button>
        </SettingsItem>
      </div>
    </div>
  )
}

function PrivacySection(): React.JSX.Element {
  const { t } = useTranslation()
  const [confirming, setConfirming] = useState(false)

  const handleClearAll = useCallback(async () => {
    if (!confirming) {
      setConfirming(true)
      return
    }
    await window.api.clearAll()
    setConfirming(false)
  }, [confirming])

  return (
    <div>
      <SectionTitle title={t('settings.privacy.title')} />
      <div className="mac-group-card overflow-hidden mb-6">
        <SettingsItem
          label={t('settings.privacy.clearAll')}
          description={t('settings.privacy.clearAll.desc')}
        >
          <Button
            variant={confirming ? 'destructive' : 'outline'}
            size="sm"
            onClick={handleClearAll}
            className={confirming ? '' : 'text-destructive hover:text-destructive'}
          >
            {confirming ? (
              t('settings.privacy.confirmClear')
            ) : (
              <>
                <Trash2 className="w-3 h-3 mr-1.5" />
                {t('settings.privacy.clearButton')}
              </>
            )}
          </Button>
        </SettingsItem>
      </div>
    </div>
  )
}

function ThemeSection(): React.JSX.Element {
  const { t } = useTranslation()
  const { theme, setTheme, accentColor, setAccentColor } = useSettingsStore(useShallow((state) => ({
    theme: state.theme,
    setTheme: state.setTheme,
    accentColor: state.accentColor,
    setAccentColor: state.setAccentColor,
  })))

  const themes: { value: ThemeMode; label: string; icon: React.ElementType }[] = [
    { value: 'auto', label: t('settings.theme.auto'), icon: Monitor },
    { value: 'light', label: t('settings.theme.light'), icon: Sun },
    { value: 'dark', label: t('settings.theme.dark'), icon: Moon },
  ]

  const presets = ['#FF7F43', '#8D6DE0', '#1A7DE8', '#22A05A', '#E83060', '#F5A623']
  const isPreset = presets.includes(accentColor)

  return (
    <div className="space-y-6">
      <div>
        <SectionTitle title={t('settings.theme.title')} />
        <div className="grid grid-cols-3 gap-3">
          {themes.map((th) => (
            <button
              key={th.value}
              onClick={() => setTheme(th.value)}
              className={cn(
                'flex flex-col items-center gap-2.5 p-3.5 rounded-xl border transition-all duration-150 active:scale-95',
                theme === th.value
                  ? 'border-primary bg-primary/10 shadow-[0_4px_12px_rgba(var(--primary),0.15)] ring-1 ring-primary/40'
                  : 'border-border/60 bg-card/60 backdrop-blur-md hover:bg-card hover:border-border'
              )}
            >
              <div className={cn(
                'flex h-8 w-8 items-center justify-center rounded-lg transition-colors',
                theme === th.value ? 'bg-primary text-primary-foreground' : 'bg-black/[0.04] dark:bg-white/[0.08] text-muted-foreground'
              )}>
                <th.icon className="w-4 h-4" />
              </div>
              <span className={cn('text-xs font-medium', theme === th.value ? 'text-primary' : 'text-muted-foreground')}>
                {th.label}
              </span>
            </button>
          ))}
        </div>
      </div>

      <div>
        <p className="text-xs font-semibold text-foreground mb-2.5 px-1">{t('settings.theme.accentColor')}</p>
        <div className="mac-group-card p-4 flex items-center gap-3 flex-wrap">
          {presets.map((color) => (
            <button
              key={color}
              title={color}
              onClick={() => setAccentColor(color)}
              className={cn(
                'w-7 h-7 rounded-full transition-all duration-150 focus:outline-none shadow-xs active:scale-90',
                accentColor === color
                  ? 'ring-2 ring-offset-2 ring-offset-background scale-110 shadow-sm'
                  : 'hover:scale-105 opacity-85 hover:opacity-100'
              )}
              style={{
                backgroundColor: color,
                ...(accentColor === color ? { ringColor: color } : {}),
              }}
            />
          ))}

          {/* Custom color picker */}
          <label
            className={cn(
              'relative w-7 h-7 rounded-full cursor-pointer flex items-center justify-center transition-all duration-150 hover:scale-105 shadow-xs active:scale-90',
              !isPreset
                ? 'ring-2 ring-offset-2 ring-offset-background scale-110 shadow-sm'
                : 'bg-black/[0.04] dark:bg-white/[0.08] border border-dashed border-border'
            )}
            style={!isPreset ? { backgroundColor: accentColor } : {}}
            title={t('settings.theme.accentCustom')}
          >
            {isPreset && <Pipette className="w-3.5 h-3.5 text-muted-foreground" />}
            <input
              type="color"
              value={accentColor}
              onChange={(e) => setAccentColor(e.target.value)}
              className="absolute inset-0 opacity-0 w-full h-full cursor-pointer rounded-full"
            />
          </label>

          {/* Hex color input */}
          <HexColorInput value={accentColor} onChange={setAccentColor} />
        </div>
      </div>
    </div>
  )
}

function TagManagementSection(): React.JSX.Element {
  const { t } = useTranslation()
  const { tags, loadTags, renameTag, deleteTag, mergeTag } = useTagStore()
  const [stats, setStats] = useState<{ total: number; singleUse: number } | null>(null)
  const [renamingSlug, setRenamingSlug] = useState<string | null>(null)
  const [renameValue, setRenameValue] = useState('')
  const [mergingSlug, setMergingSlug] = useState<string | null>(null)
  const [mergeTarget, setMergeTarget] = useState('')
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null)

  useEffect(() => {
    loadTags()
    window.api.getTagStats().then(setStats)
  }, [loadTags])

  const handleRenameConfirm = useCallback(
    async (slug: string) => {
      if (!renameValue.trim()) return
      await renameTag(slug, renameValue.trim())
      setRenamingSlug(null)
      setRenameValue('')
      const s = await window.api.getTagStats()
      setStats(s)
    },
    [renameValue, renameTag],
  )

  const handleDelete = useCallback(
    async (slug: string) => {
      if (confirmDelete === slug) {
        await deleteTag(slug)
        setConfirmDelete(null)
        const s = await window.api.getTagStats()
        setStats(s)
      } else {
        setConfirmDelete(slug)
      }
    },
    [confirmDelete, deleteTag],
  )

  const handleMerge = useCallback(
    async (sourceSlug: string) => {
      const target = mergeTarget.trim()
      if (!target) return
      await mergeTag(sourceSlug, target)
      setMergingSlug(null)
      setMergeTarget('')
      const s = await window.api.getTagStats()
      setStats(s)
    },
    [mergeTarget, mergeTag],
  )

  return (
    <div>
      <SectionTitle title={t('settings.tags.title')} />
      {stats && (
        <div className="grid grid-cols-2 gap-3 mb-4">
          <div className="mac-group-card p-3 text-center">
            <p className="text-xl font-semibold text-foreground tracking-tight">{stats.total}</p>
            <p className="text-[11px] text-muted-foreground mt-0.5">{t('settings.tags.total')}</p>
          </div>
          <div className="mac-group-card p-3 text-center">
            <p className="text-xl font-semibold text-foreground tracking-tight">{stats.singleUse}</p>
            <p className="text-[11px] text-muted-foreground mt-0.5">{t('settings.tags.singleUse')}</p>
          </div>
        </div>
      )}

      {stats && stats.total > 15 && (
        <div className="flex items-start gap-2 mb-4 px-3 py-2 bg-amber-500/10 border border-amber-500/20 rounded-xl">
          <AlertTriangle className="w-4 h-4 text-amber-600 dark:text-amber-400 shrink-0 mt-0.5" />
          <p className="text-xs text-amber-700 dark:text-amber-300">
            {t('settings.tags.tooMany')}
          </p>
        </div>
      )}

      <div className="mac-group-card divide-y divide-border/40 overflow-hidden">
        {tags.map((tag: TagWithCount) => (
          <div
            key={tag.slug}
            className="flex items-center gap-2 px-3.5 py-2.5 hover:bg-black/[0.015] dark:hover:bg-white/[0.02] group transition-colors"
          >
            <Tag className="w-3.5 h-3.5 text-muted-foreground shrink-0" />

            {renamingSlug === tag.slug ? (
              <input
                autoFocus
                value={renameValue}
                onChange={(e) => setRenameValue(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleRenameConfirm(tag.slug)
                  if (e.key === 'Escape') {
                    setRenamingSlug(null)
                    setRenameValue('')
                  }
                }}
                className="flex-1 text-xs bg-background border rounded-lg px-2 py-1 outline-none focus:ring-1 focus:ring-primary"
              />
            ) : mergingSlug === tag.slug ? (
              <select
                autoFocus
                value={mergeTarget}
                onChange={(e) => setMergeTarget(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleMerge(tag.slug)
                  if (e.key === 'Escape') {
                    setMergingSlug(null)
                    setMergeTarget('')
                  }
                }}
                className="flex-1 text-xs bg-background border rounded-lg px-2 py-1 outline-none focus:ring-1 focus:ring-primary"
              >
                <option value="">{t('settings.tags.selectTarget')}</option>
                {tags
                  .filter((tg) => tg.slug !== tag.slug)
                  .map((tg) => (
                    <option key={tg.slug} value={tg.slug}>
                      {tg.name}
                    </option>
                  ))}
              </select>
            ) : (
              <span className="flex-1 text-xs font-medium truncate">{tag.name}</span>
            )}

            <span className="text-[10px] text-muted-foreground/60 tabular-nums mr-1">
              {tag.count}
            </span>

            {renamingSlug === tag.slug ? (
              <>
                <Button
                  size="sm"
                  variant="default"
                  className="h-6 px-2 text-[11px]"
                  onClick={() => handleRenameConfirm(tag.slug)}
                >
                  {t('common.confirm')}
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-6 px-2 text-[11px]"
                  onClick={() => {
                    setRenamingSlug(null)
                    setRenameValue('')
                  }}
                >
                  {t('common.cancel')}
                </Button>
              </>
            ) : mergingSlug === tag.slug ? (
              <>
                <Button
                  size="sm"
                  variant="default"
                  className="h-6 px-2 text-[11px]"
                  onClick={() => handleMerge(tag.slug)}
                  disabled={!mergeTarget}
                >
                  {t('settings.tags.merge')}
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-6 px-2 text-[11px]"
                  onClick={() => {
                    setMergingSlug(null)
                    setMergeTarget('')
                  }}
                >
                  {t('common.cancel')}
                </Button>
              </>
            ) : (
              <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                <button
                  onClick={() => {
                    setRenamingSlug(tag.slug)
                    setRenameValue(tag.name)
                  }}
                  className="flex h-6 w-6 items-center justify-center rounded-md hover:bg-black/[0.05] dark:hover:bg-white/[0.08] text-muted-foreground hover:text-foreground transition-colors"
                  title={t('settings.tags.rename')}
                >
                  <Pencil className="w-3 h-3" />
                </button>
                <button
                  onClick={() => {
                    setMergingSlug(tag.slug)
                    setMergeTarget('')
                  }}
                  className="flex h-6 w-6 items-center justify-center rounded-md hover:bg-black/[0.05] dark:hover:bg-white/[0.08] text-muted-foreground hover:text-foreground transition-colors"
                  title={t('settings.tags.mergeTo')}
                >
                  <GitMerge className="w-3 h-3" />
                </button>
                <button
                  onClick={() => handleDelete(tag.slug)}
                  className={cn(
                    'flex h-6 w-6 items-center justify-center rounded-md hover:bg-destructive/15 transition-colors',
                    confirmDelete === tag.slug ? 'text-destructive font-semibold' : 'text-muted-foreground hover:text-destructive'
                  )}
                  title={
                    confirmDelete === tag.slug
                      ? t('settings.tags.confirmDelete')
                      : t('common.delete')
                  }
                >
                  <Trash2 className="w-3 h-3" />
                </button>
              </div>
            )}
          </div>
        ))}
        {tags.length === 0 && (
          <p className="text-xs text-muted-foreground/60 text-center py-8">
            {t('settings.tags.empty')}
          </p>
        )}
      </div>
    </div>
  )
}

function WidgetSection(): React.JSX.Element {
  const { t } = useTranslation()
  const {
    widgetFollowFilter,
    setWidgetFollowFilter,
    widgetToggleShortcut,
    setWidgetToggleShortcut,
    widgetQuickPastePrefix,
    setWidgetQuickPastePrefix,
  } = useSettingsStore(useShallow((state) => ({
    widgetFollowFilter: state.widgetFollowFilter,
    setWidgetFollowFilter: state.setWidgetFollowFilter,
    widgetToggleShortcut: state.widgetToggleShortcut,
    setWidgetToggleShortcut: state.setWidgetToggleShortcut,
    widgetQuickPastePrefix: state.widgetQuickPastePrefix,
    setWidgetQuickPastePrefix: state.setWidgetQuickPastePrefix,
  })))

  const prefixOptions = [
    { value: 'Alt', label: t('settings.shortcuts.widgetQuickPastePrefix.alt') },
    { value: 'Control', label: t('settings.shortcuts.widgetQuickPastePrefix.control') },
    { value: 'CommandOrControl', label: t('settings.shortcuts.widgetQuickPastePrefix.command') },
  ]

  return (
    <div>
      <SectionTitle title={t('settings.nav.widget')} />
      <div className="mac-group-card divide-y divide-border/40 overflow-hidden mb-6">
        <SettingsItem
          label={t('settings.general.widgetFollowFilter')}
          description={t('settings.general.widgetFollowFilter.desc')}
        >
          <Switch checked={widgetFollowFilter} onCheckedChange={setWidgetFollowFilter} />
        </SettingsItem>

        <SettingsItem
          label={t('settings.shortcuts.widgetToggle')}
          description={t('settings.shortcuts.widgetToggle.desc')}
        >
          <ShortcutRecorder value={widgetToggleShortcut} onChange={setWidgetToggleShortcut} />
        </SettingsItem>

        <SettingsItem
          label={t('settings.shortcuts.widgetQuickPastePrefix')}
          description={t('settings.shortcuts.widgetQuickPastePrefix.desc')}
        >
          <Select value={widgetQuickPastePrefix} onValueChange={setWidgetQuickPastePrefix}>
            <SelectTrigger className="w-[120px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {prefixOptions.map((opt) => (
                <SelectItem key={opt.value} value={opt.value}>
                  {opt.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </SettingsItem>
      </div>
    </div>
  )
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return bytes + ' B'
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB'
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB'
}

type UpdatePhase = 'idle' | 'checking' | 'up-to-date' | 'available' | 'downloading' | 'downloaded' | 'error' | 'download-error'

function AboutSection(): React.JSX.Element {
  const { t } = useTranslation()
  const [version, setVersion] = useState<string>('1.0.0')
  const [phase, setPhase] = useState<UpdatePhase>('idle')
  const [newVersion, setNewVersion] = useState<string>('')
  const [progress, setProgress] = useState<{ percent: number; bytesPerSecond: number; transferred: number; total: number }>({ percent: 0, bytesPerSecond: 0, transferred: 0, total: 0 })
  const [errorMsg, setErrorMsg] = useState<string>('')

  useEffect(() => {
    window.api.getVersion().then((v) => setVersion(v))

    const cleanupProgress = window.api.onUpdateProgress((data) => {
      setPhase('downloading')
      setProgress(data)
    })
    const cleanupDownloaded = window.api.onUpdateDownloaded(() => {
      setPhase('downloaded')
    })
    const cleanupError = window.api.onUpdateError((message: string) => {
      setErrorMsg(message)
      setPhase((prev) => prev === 'downloading' ? 'download-error' : 'error')
    })

    return () => {
      cleanupProgress()
      cleanupDownloaded()
      cleanupError()
    }
  }, [])

  const handleCheckUpdate = useCallback(async () => {
    setPhase('checking')
    try {
      const result = await window.api.checkForUpdates()
      if (result.status === 'available') {
        setNewVersion(result.version || '')
        setPhase('available')
      } else if (result.status === 'error') {
        setPhase('error')
      } else {
        setPhase('up-to-date')
      }
    } catch {
      setPhase('error')
    }
  }, [])

  const handleDownload = useCallback(async () => {
    setPhase('downloading')
    setProgress({ percent: 0, bytesPerSecond: 0, transferred: 0, total: 0 })
    const result = await window.api.downloadUpdate()
    if (!result.ok) {
      setPhase('download-error')
    }
  }, [])

  const handleInstall = useCallback(() => {
    window.api.installUpdate()
  }, [])

  return (
    <div>
      <SectionTitle title={t('settings.about.title')} />
      <div className="mac-group-card p-6 flex flex-col items-center text-center space-y-3.5 mb-6">
        <AppLogo size="md" />
        <div>
          <h3 className="text-base font-semibold tracking-tight text-foreground">Stash</h3>
          <p className="text-xs text-muted-foreground mt-0.5">
            {t('settings.about.version', { version })}
          </p>
        </div>
        <p className="text-xs text-muted-foreground max-w-xs leading-relaxed">{t('settings.about.description')}</p>

        <div className="flex flex-col items-center gap-2.5 w-full max-w-xs pt-1">
          {/* Check / Download / Install buttons */}
          {(phase === 'idle' || phase === 'up-to-date' || phase === 'error') && (
            <Button variant="outline" size="sm" onClick={handleCheckUpdate}>
              {t('settings.about.checkUpdate')}
            </Button>
          )}

          {phase === 'checking' && (
            <Button variant="outline" size="sm" disabled>
              <RefreshCw className="w-3 h-3 mr-2 animate-spin" />
              {t('settings.about.checking')}
            </Button>
          )}

          {phase === 'available' && (
            <Button size="sm" onClick={handleDownload}>
              <Download className="w-3 h-3 mr-2" />
              {t('settings.about.downloadUpdate')}
            </Button>
          )}

          {phase === 'download-error' && (
            <Button size="sm" variant="outline" onClick={handleDownload}>
              <RotateCcw className="w-3 h-3 mr-2" />
              {t('settings.about.downloadUpdate')}
            </Button>
          )}

          {phase === 'downloaded' && (
            <div className="flex gap-2">
              <Button size="sm" onClick={handleInstall}>
                <RotateCcw className="w-3 h-3 mr-2" />
                {t('settings.about.restartInstall')}
              </Button>
            </div>
          )}

          {/* Progress bar */}
          {phase === 'downloading' && (
            <div className="w-full space-y-1.5">
              <div className="h-1.5 w-full rounded-full bg-black/10 dark:bg-white/10 overflow-hidden">
                <motion.div
                  className="h-full rounded-full bg-primary"
                  initial={{ width: 0 }}
                  animate={{ width: `${progress.percent}%` }}
                  transition={{ duration: 0.3, ease: 'easeOut' }}
                />
              </div>
              <div className="flex justify-between text-[10px] text-muted-foreground">
                <span>{t('settings.about.downloadProgress', { percent: progress.percent })}</span>
                {progress.bytesPerSecond > 0 && (
                  <span>{t('settings.about.downloadSpeed', { speed: formatBytes(progress.bytesPerSecond) })}</span>
                )}
              </div>
            </div>
          )}

          {/* Status messages */}
          {phase === 'up-to-date' && (
            <p className="text-xs text-emerald-600 dark:text-emerald-400 flex items-center gap-1 font-medium">
              <CheckCircle2 className="w-3.5 h-3.5" />
              <span>{t('settings.about.upToDate')}</span>
            </p>
          )}
          {(phase === 'available' || phase === 'downloading') && (
            <p className="text-xs text-primary font-medium">
              {t('settings.about.updateAvailable', { version: newVersion })}
            </p>
          )}
          {phase === 'downloaded' && (
            <p className="text-xs text-emerald-600 dark:text-emerald-400 flex items-center gap-1 font-medium">
              <CheckCircle2 className="w-3.5 h-3.5" />
              <span>{t('settings.about.downloadReady')}</span>
            </p>
          )}
          {phase === 'error' && (
            <p className="text-xs text-destructive">{t('settings.about.checkFailed')}</p>
          )}
          {phase === 'download-error' && (
            <div className="text-xs text-destructive text-center">
              <p>{t('settings.about.downloadFailed')}</p>
              {errorMsg && <p className="mt-1 text-[10px] text-muted-foreground break-all">{errorMsg}</p>}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

function HexColorInput({ value, onChange }: { value: string; onChange: (v: string) => void }): React.JSX.Element {
  const [draft, setDraft] = useState(value)
  useEffect(() => setDraft(value), [value])

  return (
    <input
      type="text"
      value={draft}
      onChange={(e) => {
        const v = e.target.value
        if (/^#?[0-9A-Fa-f]{0,6}$/.test(v)) {
          setDraft(v)
          if (/^#[0-9A-Fa-f]{6}$/.test(v)) onChange(v)
        }
      }}
      onBlur={() => {
        if (/^#[0-9A-Fa-f]{6}$/.test(draft)) onChange(draft)
        else setDraft(value)
      }}
      onKeyDown={(e) => {
        if (e.key === 'Enter' && /^#[0-9A-Fa-f]{6}$/.test(draft)) onChange(draft)
      }}
      placeholder="#FF7F43"
      className="w-20 h-7 px-2 text-xs font-mono rounded-lg border border-border/70 bg-black/[0.03] dark:bg-white/[0.06] text-foreground focus:outline-none focus:ring-1 focus:ring-primary shadow-[inset_0_1px_1.5px_rgba(0,0,0,0.05)]"
    />
  )
}

export default memo(SettingsPage)
