import { memo, useState, useCallback, useEffect, useRef } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useSettingsStore, ThemeMode, LanguageMode, LayoutMode } from '../../stores/settingsStore'
import { useTagStore, TagWithCount } from '../../stores/tagStore'
import { useLicenseStore } from '../../stores/licenseStore'
import { useShallow } from 'zustand/react/shallow'
import { Switch } from '../ui/switch'
import { AppLogo } from '../ui/app-logo'
import { Input } from '../ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../ui/select'
import { Button } from '../ui/button'
import { Separator } from '../ui/separator'
import { showToast } from '../../utils/toast'
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
  Crown,
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
  | 'license'
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
    { id: 'license', label: t('license.nav'), icon: Crown },
    { id: 'about', label: t('settings.nav.about'), icon: Info },
  ]

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95, y: 20 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      transition={{ duration: 0.3, ease: 'easeOut' }}
      className="flex flex-col h-full bg-background text-foreground rounded-[1.5rem] border border-border/70 overflow-hidden"
    >
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 border-b">
        <h1 className="text-lg font-semibold">{t('settings.title')}</h1>
        <Button variant="ghost" size="sm" onClick={onClose}>
          {t('common.close')}
        </Button>
      </div>

      <div className="flex flex-1 min-h-0">
        {/* Left nav */}
        <div className="w-48 shrink-0 border-r py-4">
          {sections.map((section) => (
            <button
              key={section.id}
              onClick={() => setActiveSection(section.id)}
              className={`w-full text-left px-6 py-2 text-sm transition-colors flex items-center gap-3 ${
                activeSection === section.id
                  ? 'bg-primary text-primary-foreground font-medium'
                  : 'text-muted-foreground hover:bg-muted/50 hover:text-foreground'
              }`}
            >
              <section.icon className="w-4 h-4" />
              {section.label}
            </button>
          ))}
        </div>

        {/* Right content */}
        <div className="flex-1 overflow-y-auto px-8 py-6">
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
    case 'license':
      return <LicenseSection />
    case 'about':
      return <AboutSection />
    default:
      return <GeneralSection />
  }
}

function SectionTitle({ title }: { title: string }): React.JSX.Element {
  return (
    <h2 className="text-sm font-medium text-muted-foreground uppercase tracking-wider mb-4">
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
    <div className="flex items-center justify-between py-4">
      <div className="flex-1 min-w-0 mr-4">
        <p className="text-sm font-medium">{label}</p>
        {description && <p className="text-xs text-muted-foreground mt-1">{description}</p>}
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
      <SettingsItem
        label={t('settings.general.language')}
        description={t('settings.general.language.desc')}
      >
        <Select value={language} onValueChange={(v) => setLanguage(v as LanguageMode)}>
          <SelectTrigger className="w-[160px]">
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
      <Separator />
      <SettingsItem
        label={t('settings.general.layoutMode')}
        description={t('settings.general.layoutMode.desc')}
      >
        <Select value={layoutMode} onValueChange={(v) => setLayoutMode(v as LayoutMode)}>
          <SelectTrigger className="w-[160px]">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="center">{t('settings.general.layoutMode.center')}</SelectItem>
            <SelectItem value="side">{t('settings.general.layoutMode.side')}</SelectItem>
            <SelectItem value="bottom">{t('settings.general.layoutMode.bottom')}</SelectItem>
          </SelectContent>
        </Select>
      </SettingsItem>
      <Separator />
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
      <Separator />
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
      <Separator />
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
                  className="h-9 w-[140px] text-right"
                />
                <Button size="sm" onClick={saveCustomMaxItems} disabled={!canSaveCustomMaxItems}>
                  {t('common.save')}
                </Button>
              </div>
              <p className="text-[11px] text-muted-foreground">
                {t('settings.general.maxItems.customHint', {
                  min: MAX_ITEMS_CUSTOM_MIN,
                })}
              </p>
            </div>
          )}
        </div>
      </SettingsItem>
    </div>
  )
}

import { formatShortcut, eventToShortcut } from '../../utils/shortcut'

function ShortcutBadge({ shortcut }: { shortcut: string }): React.JSX.Element {
  return (
    <div className="bg-muted px-3 py-1.5 rounded-md text-sm font-mono border">
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
      className={`px-3 py-1.5 rounded-md text-sm font-mono border transition-colors min-w-[80px] text-center ${
        recording
          ? 'border-primary bg-primary/10 text-primary animate-pulse'
          : 'bg-muted hover:border-primary/50'
      }`}
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
      <SettingsItem
        label={t('settings.shortcuts.showPanel')}
        description={t('settings.shortcuts.showPanel.desc')}
      >
        <ShortcutBadge shortcut={customShortcut} />
      </SettingsItem>
      <Separator />
      <SettingsItem
        label={t('settings.shortcuts.sequencePaste')}
        description={t('settings.shortcuts.sequencePaste.desc')}
      >
        <ShortcutBadge shortcut={sequencePasteShortcut} />
      </SettingsItem>
      <Separator />
      <SettingsItem
        label={t('settings.shortcuts.batchPaste')}
        description={t('settings.shortcuts.batchPaste.desc')}
      >
        <ShortcutBadge shortcut={batchPasteShortcut} />
      </SettingsItem>
      <Separator />
      <SettingsItem
        label={t('settings.shortcuts.addToQueue')}
        description={t('settings.shortcuts.addToQueue.desc')}
      >
        <ShortcutBadge shortcut="Space" />
      </SettingsItem>
      <Separator />
      <SettingsItem
        label={t('settings.shortcuts.toggleFilter')}
        description={t('settings.shortcuts.toggleFilter.desc')}
      >
        <ShortcutRecorder value={toggleFilterShortcut} onChange={setToggleFilterShortcut} />
      </SettingsItem>
      <Separator />
      <SettingsItem
        label={t('settings.shortcuts.togglePreview')}
        description={t('settings.shortcuts.togglePreview.desc')}
      >
        <ShortcutRecorder value={togglePreviewShortcut} onChange={setTogglePreviewShortcut} />
      </SettingsItem>
      <Separator />
      <SettingsItem
        label={t('settings.shortcuts.openTag')}
        description={t('settings.shortcuts.openTag.desc')}
      >
        <ShortcutRecorder value={openTagShortcut} onChange={setOpenTagShortcut} />
      </SettingsItem>
      <Separator />
      <SettingsItem
        label={t('settings.shortcuts.openSettings')}
        description={t('settings.shortcuts.openSettings.desc')}
      >
        <ShortcutRecorder value={openSettingsShortcut} onChange={setOpenSettingsShortcut} />
      </SettingsItem>
      <Separator />
      <SettingsItem
        label={t('settings.shortcuts.cycleLayout')}
        description={t('settings.shortcuts.cycleLayout.desc')}
      >
        <ShortcutRecorder value={cycleLayoutShortcut} onChange={(v) => {
          setCycleLayoutShortcut(v)
          window.api.updateShortcuts({ cycleLayout: v })
        }} />
      </SettingsItem>
      <Separator />
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
      <p className="text-xs text-muted-foreground mt-4">{t('settings.shortcuts.hint')}</p>
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
      <SettingsItem label={t('settings.sync.enable')} description={t('settings.sync.enable.desc')}>
        <Switch checked={iCloudSync} onCheckedChange={setICloudSync} />
      </SettingsItem>
      <Separator />
      <SettingsItem label={t('settings.sync.now')} description={t('settings.sync.now.desc')}>
        <Button
          variant="outline"
          size="sm"
          onClick={handleSyncNow}
          disabled={!iCloudSync || syncing}
        >
          {syncing ? (
            <>
              <RefreshCw className="w-3 h-3 mr-2 animate-spin" />
              {t('settings.sync.syncing')}
            </>
          ) : (
            t('settings.sync.syncButton')
          )}
        </Button>
      </SettingsItem>
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
              <Trash2 className="w-3 h-3 mr-2" />
              {t('settings.privacy.clearButton')}
            </>
          )}
        </Button>
      </SettingsItem>
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
    { value: 'dark', label: t('settings.theme.dark'), icon: Moon },
    { value: 'light', label: t('settings.theme.light'), icon: Sun },
  ]

  const presets = ['#FF7F43', '#8D6DE0', '#1A7DE8', '#22A05A', '#E83060', '#F5A623']
  const isPreset = presets.includes(accentColor)

  return (
    <div className="space-y-6">
      <div>
        <SectionTitle title={t('settings.theme.title')} />
        <div className="grid grid-cols-3 gap-4">
          {themes.map((th) => (
            <button
              key={th.value}
              onClick={() => setTheme(th.value)}
              className={`flex flex-col items-center gap-3 p-4 rounded-lg border-2 transition-all ${
                theme === th.value
                  ? 'border-primary bg-primary/5'
                  : 'border-transparent bg-muted hover:bg-muted/80'
              }`}
            >
              <th.icon
                className={`w-6 h-6 ${theme === th.value ? 'text-primary' : 'text-muted-foreground'}`}
              />
              <span
                className={`text-sm font-medium ${theme === th.value ? 'text-primary' : 'text-muted-foreground'}`}
              >
                {th.label}
              </span>
            </button>
          ))}
        </div>
      </div>

      <div>
        <p className="text-sm font-semibold text-foreground mb-3">{t('settings.theme.accentColor')}</p>
        <div className="flex items-center gap-3 flex-wrap">
          {presets.map((color) => (
            <button
              key={color}
              title={color}
              onClick={() => setAccentColor(color)}
              className={`w-8 h-8 rounded-full transition-all focus:outline-none ${
                accentColor === color
                  ? 'ring-2 ring-offset-2 ring-offset-background scale-110'
                  : 'hover:scale-105 opacity-80 hover:opacity-100'
              }`}
              style={{
                backgroundColor: color,
                ...(accentColor === color ? { ringColor: color } : {}),
              }}
            />
          ))}

          {/* Custom color picker */}
          <label
            className={`relative w-8 h-8 rounded-full cursor-pointer flex items-center justify-center transition-all hover:scale-105 ${
              !isPreset
                ? 'ring-2 ring-offset-2 ring-offset-background scale-110'
                : 'bg-muted border border-dashed border-muted-foreground'
            }`}
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
        <div className="flex gap-4 mb-4">
          <div className="flex-1 bg-muted/40 rounded-lg p-3 text-center">
            <p className="text-xl font-semibold">{stats.total}</p>
            <p className="text-xs text-muted-foreground mt-0.5">{t('settings.tags.total')}</p>
          </div>
          <div className="flex-1 bg-muted/40 rounded-lg p-3 text-center">
            <p className="text-xl font-semibold">{stats.singleUse}</p>
            <p className="text-xs text-muted-foreground mt-0.5">{t('settings.tags.singleUse')}</p>
          </div>
        </div>
      )}

      {stats && stats.total > 15 && (
        <div className="flex items-start gap-2 mb-4 px-3 py-2 bg-yellow-500/10 border border-yellow-500/20 rounded-lg">
          <AlertTriangle className="w-4 h-4 text-yellow-600 dark:text-yellow-400 shrink-0 mt-0.5" />
          <p className="text-xs text-yellow-700 dark:text-yellow-300">
            {t('settings.tags.tooMany')}
          </p>
        </div>
      )}

      <div className="space-y-1">
        {tags.map((tag: TagWithCount) => (
          <div
            key={tag.slug}
            className="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-muted/40 group"
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
                className="flex-1 text-sm bg-background border rounded px-2 py-0.5 outline-none focus:ring-1 focus:ring-primary"
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
                className="flex-1 text-sm bg-background border rounded px-2 py-0.5 outline-none focus:ring-1 focus:ring-primary"
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
              <span className="flex-1 text-sm truncate">{tag.name}</span>
            )}

            <span className="text-[10px] text-muted-foreground/60 tabular-nums mr-1">
              {tag.count}
            </span>

            {renamingSlug === tag.slug ? (
              <>
                <Button
                  size="sm"
                  variant="default"
                  className="h-6 px-2 text-xs"
                  onClick={() => handleRenameConfirm(tag.slug)}
                >
                  {t('common.confirm')}
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-6 px-2 text-xs"
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
                  className="h-6 px-2 text-xs"
                  onClick={() => handleMerge(tag.slug)}
                  disabled={!mergeTarget}
                >
                  {t('settings.tags.merge')}
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-6 px-2 text-xs"
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
                  className="p-1 rounded hover:bg-background/80 text-muted-foreground"
                  title={t('settings.tags.rename')}
                >
                  <Pencil className="w-3.5 h-3.5" />
                </button>
                <button
                  onClick={() => {
                    setMergingSlug(tag.slug)
                    setMergeTarget('')
                  }}
                  className="p-1 rounded hover:bg-background/80 text-muted-foreground"
                  title={t('settings.tags.mergeTo')}
                >
                  <GitMerge className="w-3.5 h-3.5" />
                </button>
                <button
                  onClick={() => handleDelete(tag.slug)}
                  className={`p-1 rounded hover:bg-background/80 ${confirmDelete === tag.slug ? 'text-destructive' : 'text-muted-foreground'}`}
                  title={
                    confirmDelete === tag.slug
                      ? t('settings.tags.confirmDelete')
                      : t('common.delete')
                  }
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            )}
          </div>
        ))}
        {tags.length === 0 && (
          <p className="text-sm text-muted-foreground text-center py-8">
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
      <SettingsItem
        label={t('settings.general.widgetFollowFilter')}
        description={t('settings.general.widgetFollowFilter.desc')}
      >
        <Select
          value={widgetFollowFilter ? 'follow' : 'independent'}
          onValueChange={(v) => {
            const follow = v === 'follow'
            setWidgetFollowFilter(follow)
            window.api.widgetSetFollowFilter(follow)
          }}
        >
          <SelectTrigger className="w-[180px]">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="independent">
              {t('settings.general.widgetFollowFilter.independent')}
            </SelectItem>
            <SelectItem value="follow">
              {t('settings.general.widgetFollowFilter.follow')}
            </SelectItem>
          </SelectContent>
        </Select>
      </SettingsItem>
      <Separator />
      <SettingsItem
        label={t('settings.shortcuts.widgetToggle')}
        description={t('settings.shortcuts.widgetToggle.desc')}
      >
        <ShortcutRecorder
          value={widgetToggleShortcut}
          onChange={(v) => {
            setWidgetToggleShortcut(v)
            window.api.updateShortcuts({ widgetToggle: v })
          }}
        />
      </SettingsItem>
      <Separator />
      <SettingsItem
        label={t('settings.shortcuts.widgetQuickPastePrefix')}
        description={t('settings.shortcuts.widgetQuickPastePrefix.desc')}
      >
        <Select
          value={widgetQuickPastePrefix}
          onValueChange={(v) => {
            setWidgetQuickPastePrefix(v)
            window.api.updateShortcuts({ widgetQuickPastePrefix: v })
          }}
        >
          <SelectTrigger className="w-[160px]">
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
  )
}

function LicenseSection(): React.JSX.Element {
  const { t } = useTranslation()
  const { type, trialDaysLeft, activationCode, loading, fetchStatus, activate, deactivate } =
    useLicenseStore()
  const [code, setCode] = useState('')
  const [activating, setActivating] = useState(false)
  const [error, setError] = useState('')
  const [confirmDeactivate, setConfirmDeactivate] = useState(false)

  useEffect(() => {
    fetchStatus()
  }, [fetchStatus])

  const handleActivate = useCallback(async () => {
    if (!code.trim()) return
    setActivating(true)
    setError('')
    const result = await activate(code.trim())
    setActivating(false)
    if (result.ok) {
      setCode('')
      showToast(t('license.activateSuccess'))
    } else {
      setError(t('license.activateError'))
    }
  }, [code, activate, t])

  const handleDeactivate = useCallback(async () => {
    if (!confirmDeactivate) {
      setConfirmDeactivate(true)
      setTimeout(() => setConfirmDeactivate(false), 3000)
      return
    }
    await deactivate()
    setConfirmDeactivate(false)
  }, [confirmDeactivate, deactivate])

  if (loading) {
    return (
      <div>
        <SectionTitle title={t('license.title')} />
        <p className="text-sm text-muted-foreground py-8 text-center">...</p>
      </div>
    )
  }

  return (
    <div>
      <SectionTitle title={t('license.title')} />

      {/* Status display */}
      <SettingsItem label={t('license.status')} description={t('license.status.desc')}>
        {type === 'activated' ? (
          <span className="inline-flex items-center gap-1.5 rounded-full bg-green-500/15 px-3 py-1 text-xs font-semibold text-green-600 dark:text-green-400">
            <span className="h-1.5 w-1.5 rounded-full bg-green-500" />
            {t('license.activated')}
          </span>
        ) : type === 'trial' ? (
          <span className="inline-flex items-center gap-1.5 rounded-full bg-blue-500/15 px-3 py-1 text-xs font-semibold text-blue-600 dark:text-blue-400">
            <span className="h-1.5 w-1.5 rounded-full bg-blue-500" />
            {t('license.trialActive', { days: trialDaysLeft })}
          </span>
        ) : (
          <span className="inline-flex items-center gap-1.5 rounded-full bg-red-500/15 px-3 py-1 text-xs font-semibold text-red-600 dark:text-red-400">
            <span className="h-1.5 w-1.5 rounded-full bg-red-500" />
            {t('license.expired')}
          </span>
        )}
      </SettingsItem>

      {type === 'activated' && activationCode && (
        <>
          <Separator />
          <SettingsItem label={t('license.currentCode')}>
            <span className="font-mono text-xs text-muted-foreground tracking-wider">
              {activationCode.slice(0, 4)}–••••–••••–{activationCode.slice(-4)}
            </span>
          </SettingsItem>
        </>
      )}

      <Separator />

      {/* Activation input (show when not activated) */}
      {type !== 'activated' && (
        <>
          {type === 'expired' && (
            <div className="mb-4 rounded-xl border border-red-500/30 bg-red-500/5 p-4">
              <p className="text-sm text-red-600 dark:text-red-400">
                {t('license.expiredDesc')}
              </p>
            </div>
          )}
          <SettingsItem label={t('license.code')} description={t('license.code.desc')}>
            <div className="flex items-center gap-2">
              <Input
                value={code}
                onChange={(e) => {
                  setCode(e.target.value)
                  setError('')
                }}
                placeholder={t('license.codePlaceholder')}
                className="w-[220px] font-mono text-xs tracking-wider"
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleActivate()
                }}
              />
              <Button size="sm" onClick={handleActivate} disabled={activating || !code.trim()}>
                {activating ? t('license.activating') : t('license.activate')}
              </Button>
            </div>
          </SettingsItem>
          {error && (
            <p className="text-xs text-destructive mt-1 mb-3 flex items-center gap-1.5">
              <AlertTriangle className="w-3.5 h-3.5" />
              {error}
            </p>
          )}
          <Separator />
          {/* Buy CTA - hidden for now */}
        </>
      )}

      {/* Deactivate (show when activated) */}
      {type === 'activated' && (
        <>
          <SettingsItem
            label={t('license.deactivate')}
            description={t('license.deactivate.desc')}
          >
            <Button
              variant={confirmDeactivate ? 'destructive' : 'outline'}
              size="sm"
              onClick={handleDeactivate}
            >
              {confirmDeactivate ? t('license.deactivateConfirm') : t('license.deactivate')}
            </Button>
          </SettingsItem>
        </>
      )}
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
      <div className="flex flex-col items-center py-8 text-center space-y-4">
        <AppLogo size="md" />
        <div>
          <h3 className="text-lg font-semibold">Stash</h3>
          <p className="text-sm text-muted-foreground">
            {t('settings.about.version', { version })}
          </p>
        </div>
        <p className="text-sm text-muted-foreground max-w-xs">{t('settings.about.description')}</p>

        <div className="flex flex-col items-center gap-3 w-full max-w-xs">
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
              <div className="h-2 w-full rounded-full bg-muted overflow-hidden">
                <motion.div
                  className="h-full rounded-full bg-primary"
                  initial={{ width: 0 }}
                  animate={{ width: `${progress.percent}%` }}
                  transition={{ duration: 0.3, ease: 'easeOut' }}
                />
              </div>
              <div className="flex justify-between text-[11px] text-muted-foreground">
                <span>{t('settings.about.downloadProgress', { percent: progress.percent })}</span>
                {progress.bytesPerSecond > 0 && (
                  <span>{t('settings.about.downloadSpeed', { speed: formatBytes(progress.bytesPerSecond) })}</span>
                )}
              </div>
            </div>
          )}

          {/* Status messages */}
          {phase === 'up-to-date' && (
            <p className="text-xs text-green-600 dark:text-green-400 flex items-center gap-1">
              <CheckCircle2 className="w-3 h-3" />
              {t('settings.about.upToDate')}
            </p>
          )}
          {(phase === 'available' || phase === 'downloading') && (
            <p className="text-xs text-primary">
              {t('settings.about.updateAvailable', { version: newVersion })}
            </p>
          )}
          {phase === 'downloaded' && (
            <p className="text-xs text-green-600 dark:text-green-400 flex items-center gap-1">
              <CheckCircle2 className="w-3 h-3" />
              {t('settings.about.downloadReady')}
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
      className="w-[5.5rem] h-8 px-2 text-xs font-mono rounded-md border border-border bg-muted text-foreground focus:outline-none focus:ring-1 focus:ring-primary"
    />
  )
}

export default memo(SettingsPage)
