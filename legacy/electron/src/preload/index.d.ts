import { ElectronAPI } from '@electron-toolkit/preload'

interface ClipboardItem {
  id: string
  content: string
  content_type: string
  content_hash: string
  preview: string | null
  metadata: string | null
  is_favorite: number
  is_pinned: number
  source_app: string | null
  tags: string | null
  title: string | null
  category_id: string | null
  created_at: number
  updated_at: number
  use_count: number
  tag_slugs?: string | null
}

type LeftFilter =
  | { type: 'all' }
  | { type: 'starred' }
  | { type: 'tag'; slug: string }

interface TagWithCount {
  id: string
  slug: string
  name: string
  created_at: number
  updated_at: number
  last_used_at: number | null
  count: number
}

interface ZPasteAPI {
  getItems: (options?: {
    limit?: number
    offset?: number
    contentType?: string
    favoritesOnly?: boolean
    leftFilter?: LeftFilter
    sourceApp?: string
    sortBy?: 'recent' | 'usage'
    includeContent?: boolean
  }) => Promise<ClipboardItem[]>
  getItemContent: (id: string) => Promise<{
    content: string
    content_type: string
    metadata: string | null
  } | null>
  searchItems: (query: string) => Promise<ClipboardItem[]>
  deleteItem: (id: string) => Promise<void>
  toggleFavorite: (id: string) => Promise<void>
  togglePin: (id: string) => Promise<void>
  pasteItem: (id: string) => Promise<void>
  updateItemTitle: (id: string, title: string | null) => Promise<void>
  clearAll: () => Promise<void>
  getStarredCount: () => Promise<number>
  getCategories: () => Promise<Array<{ id: string; name: string; color: string | null; sort_order: number; created_at: number }>>
  createCategory: (id: string, name: string, color: string | null) => Promise<void>
  deleteCategory: (id: string) => Promise<void>
  updateItemCategory: (itemId: string, categoryId: string | null) => Promise<void>
  getTemplates: () => Promise<Array<{ id: string; name: string; content: string; category_id: string | null; sort_order: number; created_at: number; updated_at: number }>>
  createTemplate: (id: string, name: string, content: string, categoryId?: string) => Promise<void>
  updateTemplate: (id: string, name: string, content: string) => Promise<void>
  deleteTemplate: (id: string) => Promise<void>
  setLaunchAtLogin: (enabled: boolean) => Promise<void>
  getLaunchAtLogin: () => Promise<boolean>
  setLanguage: (lang: string) => Promise<void>
  setTheme: (theme: string) => Promise<void>
  setAccentColor: (color: string) => Promise<void>
  setMaxItems: (value: number) => Promise<number>
  onThemeChanged: (callback: (theme: string) => void) => () => void
  onAccentColorChanged: (callback: (color: string) => void) => () => void
  setLayoutMode: (mode: string) => Promise<void>
  onLayoutModeChanged: (callback: (mode: string) => void) => () => void
  openSettingsWindow: (view?: string) => Promise<void>
  syncNow: () => Promise<void>
  syncStart: () => Promise<void>
  syncStop: () => Promise<void>
  listTags: () => Promise<TagWithCount[]>
  applyTags: (itemId: string, slugs: string[]) => Promise<void>
  removeTag: (itemId: string, slug: string) => Promise<void>
  getItemTagSlugs: (itemId: string) => Promise<string[]>
  renameTag: (slug: string, nextName: string) => Promise<void>
  deleteTag: (slug: string) => Promise<void>
  mergeTag: (sourceSlug: string, targetSlug: string) => Promise<void>
  getTagStats: () => Promise<{ total: number; singleUse: number }>
  getSimilarTags: (name: string) => Promise<TagWithCount[]>
  // Source app
  getSourceApps: () => Promise<{ name: string; bundleId: string; count: number }[]>
  getContentTypeCounts: (options?: { leftFilter?: LeftFilter; sourceApp?: string }) => Promise<Record<string, number>>
  getAppIcon: (bundleId: string) => Promise<string | null>
  // Sequence paste queue
  queueAdd: (item: { id: string; content: string; content_type: string }) => Promise<number>
  queueAddMultiple: (items: { id: string; content: string; content_type: string }[]) => Promise<number>
  queueClear: () => Promise<void>
  queueGetCount: () => Promise<number>
  queueGetItems: () => Promise<{ id: string; content: string }[]>
  queueSetSeparator: (separator: string) => Promise<void>
  updateShortcuts: (config: { panelShortcut?: string; sequencePaste?: string; batchPaste?: string; widgetToggle?: string; widgetQuickPastePrefix?: string; cycleLayout?: string }) => Promise<void>
  onQueueUpdated: (callback: (data: { count: number }) => void) => () => void
  onQueuePasted: (callback: (data: { index: number; total: number }) => void) => () => void
  onQueueBatchPasted: (callback: (data: { count: number }) => void) => () => void
  onQueueFinished: (callback: () => void) => () => void
  onNewItem: (callback: (item: ClipboardItem) => void) => () => void
  onPanelShown: (callback: () => void) => () => void
  onPanelHidden: (callback: () => void) => () => void
  // Widget
  widgetSetPinned: (pinned: boolean) => Promise<void>
  widgetSavePosition: (x: number, y: number) => Promise<void>
  widgetSyncFilter: (filter: { contentType?: string; leftFilter?: unknown; sourceApp?: string; sortBy?: string }) => Promise<void>
  widgetSetFollowFilter: (value: boolean) => Promise<void>
  onWidgetShown: (callback: () => void) => () => void
  onWidgetPinnedChanged: (callback: (pinned: boolean) => void) => () => void
  // App info
  getVersion: () => Promise<string>
  checkForUpdates: () => Promise<{ status: 'available' | 'up-to-date' | 'not-available' | 'error'; version?: string; message?: string }>
  downloadUpdate: () => Promise<{ ok: boolean; error?: string }>
  installUpdate: () => Promise<void>
  onUpdateProgress: (callback: (data: { percent: number; bytesPerSecond: number; transferred: number; total: number }) => void) => () => void
  onUpdateDownloaded: (callback: () => void) => () => void
  onUpdateError: (callback: (message: string) => void) => () => void
}

declare global {
  interface Window {
    electron: ElectronAPI
    api: ZPasteAPI
  }
}
