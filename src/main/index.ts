import { app, BrowserWindow, ipcMain, dialog, Menu } from 'electron'
import { electronApp, optimizer } from '@electron-toolkit/utils'
import { WindowManager } from './window'
import { WidgetWindowManager } from './widget'
import { ShortcutManager } from './shortcuts'
import { writeItemToClipboard } from './clipboard/paste-utils'
import { TrayManager } from './tray'
import { SettingsWindowManager } from './settings-window'
import { ClipboardMonitor } from './clipboard/monitor'
import { initDatabase, getDatabase } from './database/connection'
import { createTables } from './database/schema'
import * as repository from './database/repository'
import { iCloudSync } from './sync/icloud'
import { getAppIcon } from './clipboard/app-icon'
import { exec } from 'child_process'
import { autoUpdater } from 'electron-updater'
import { DEFAULT_MAX_ITEMS, normalizeMaxItems } from '../shared/max-items'
import * as license from './license'
import { setDesktopLanguage, translateDesktop } from './localization'

let windowManager: WindowManager
let widgetManager: WidgetWindowManager
let shortcutManager: ShortcutManager
let trayManager: TrayManager
let settingsWindowManager: SettingsWindowManager
let clipboardMonitor: ClipboardMonitor
let syncService: iCloudSync | null = null
let cleanupMaxItems = DEFAULT_MAX_ITEMS
let appLanguage = setDesktopLanguage(app.getLocale())

function broadcastToAllWindows(channel: string, ...args: unknown[]): void {
  for (const win of BrowserWindow.getAllWindows()) {
    if (!win.isDestroyed()) {
      win.webContents.send(channel, ...args)
    }
  }
}

function setApplicationMenu(language: string): void {
  appLanguage = setDesktopLanguage(language)

  Menu.setApplicationMenu(
    Menu.buildFromTemplate([
      {
        label: app.name,
        submenu: [{ role: 'quit' }]
      },
      {
        label: translateDesktop('menu.edit', appLanguage),
        submenu: [
          { role: 'undo' },
          { role: 'redo' },
          { type: 'separator' },
          { role: 'cut' },
          { role: 'copy' },
          { role: 'paste' },
          { role: 'selectAll' }
        ]
      },
      {
        label: translateDesktop('menu.view', appLanguage),
        submenu: [{ role: 'zoomIn' }, { role: 'zoomOut' }, { role: 'resetZoom' }]
      }
    ])
  )
}

function setupAutoUpdater(): void {
  if (!app.isPackaged) return

  autoUpdater.autoDownload = false
  autoUpdater.autoInstallOnAppQuit = true

  autoUpdater.on('download-progress', (progress) => {
    const data = {
      percent: Math.round(progress.percent),
      bytesPerSecond: progress.bytesPerSecond,
      transferred: progress.transferred,
      total: progress.total,
    }
    broadcastToAllWindows('updater:download-progress', data)
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) win.setProgressBar(data.percent / 100)
    }
  })

  autoUpdater.on('update-downloaded', () => {
    broadcastToAllWindows('updater:downloaded')
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) win.setProgressBar(-1)
    }
    dialog
      .showMessageBox({
        type: 'info',
        title: translateDesktop('updater.dialog.downloadedTitle'),
        message: translateDesktop('updater.dialog.downloadedMessage'),
        buttons: [
          translateDesktop('updater.dialog.restartNow'),
          translateDesktop('updater.dialog.later')
        ],
        defaultId: 0,
        cancelId: 1,
      })
      .then(({ response }) => {
        if (response === 0) {
          autoUpdater.quitAndInstall()
        }
      })
  })

  autoUpdater.on('error', (err) => {
    console.error('[updater] error:', err.message, err.stack)
    broadcastToAllWindows('updater:error', err.message)
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) win.setProgressBar(-1)
    }
  })

  ipcMain.handle('updater:downloadUpdate', async () => {
    try {
      await autoUpdater.downloadUpdate()
      return { ok: true }
    } catch (err) {
      return { ok: false, error: (err as Error).message }
    }
  })

  ipcMain.handle('updater:install', () => {
    autoUpdater.quitAndInstall()
  })

  autoUpdater.on('update-available', (info) => {
    const version = info.version
    const title = translateDesktop('updater.dialog.title')
    const message = translateDesktop('updater.dialog.message', undefined, { version })
    dialog
      .showMessageBox({
        type: 'info',
        title,
        message,
        buttons: [
          translateDesktop('updater.dialog.update'),
          translateDesktop('updater.dialog.later')
        ],
        defaultId: 0,
        cancelId: 1
      })
      .then(({ response }) => {
        if (response === 0) {
          autoUpdater.downloadUpdate().catch(() => {})
          broadcastToAllWindows('updater:download-progress', {
            percent: 0,
            bytesPerSecond: 0,
            transferred: 0,
            total: 0
          })
        }
      })
  })

  autoUpdater.checkForUpdates().catch(() => {})
  const updateIntervalId = setInterval(() => {
    autoUpdater.checkForUpdates().catch(() => {})
  }, 60 * 60 * 1000)
  app.on('will-quit', () => clearInterval(updateIntervalId))
}

app.whenReady().then(() => {
  electronApp.setAppUserModelId('com.zpaste.app')

  // Set application menu with zoom shortcuts (Cmd+-, Cmd+=, Cmd+0)
  setApplicationMenu(appLanguage)

  // Hide dock icon — only show in menu bar tray
  if (app.dock) app.dock.hide()

  app.on('browser-window-created', (_, window) => {
    optimizer.watchWindowShortcuts(window)
  })

  initDatabase()
  createTables()

  windowManager = new WindowManager()
  widgetManager = new WidgetWindowManager()
  shortcutManager = new ShortcutManager(windowManager)
  shortcutManager.setWidgetManager(widgetManager)
  trayManager = new TrayManager(windowManager)
  trayManager.setLanguage(appLanguage)
  settingsWindowManager = new SettingsWindowManager()
  settingsWindowManager.onClosed(() => {
    windowManager.show()
  })
  clipboardMonitor = new ClipboardMonitor()

  shortcutManager.register()
  trayManager.create()
  clipboardMonitor.start()
  setupAutoUpdater()

  // Show main window on startup
  windowManager.create()
  windowManager.show()

  // Auto cleanup every 10 minutes
  setInterval(() => {
    repository.autoCleanup(cleanupMaxItems)
  }, 10 * 60 * 1000)

  // IPC handlers
  // App info
  ipcMain.handle('app:getVersion', async () => {
    return app.getVersion()
  })

  ipcMain.handle('app:checkForUpdates', async () => {
    if (!app.isPackaged) {
      return { status: 'not-available', message: 'dev-mode' }
    }
    try {
      const result = await autoUpdater.checkForUpdates()
      if (result && result.updateInfo) {
        const currentVersion = app.getVersion()
        const latestVersion = result.updateInfo.version
        if (latestVersion !== currentVersion) {
          return { status: 'available', version: latestVersion }
        }
      }
      return { status: 'up-to-date' }
    } catch {
      return { status: 'error' }
    }
  })

  // License IPC handlers
  ipcMain.handle('license:getStatus', async () => {
    return license.getLicenseStatus()
  })

  ipcMain.handle('license:activate', async (_, code: string) => {
    return license.activateLicense(code)
  })

  ipcMain.handle('license:deactivate', async () => {
    license.deactivateLicense()
  })

  ipcMain.handle('clipboard:getItems', async (_, options) => {
    return repository.getItems(options)
  })

  ipcMain.handle('clipboard:getItemContent', async (_, id: string) => {
    return repository.getItemContent(id) ?? null
  })

  ipcMain.handle('clipboard:searchItems', async (_, query) => {
    return repository.searchItems(query)
  })

  ipcMain.handle('clipboard:deleteItem', async (_, id: string) => {
    return repository.deleteItem(id)
  })

  ipcMain.handle('clipboard:toggleFavorite', async (_, id: string) => {
    return repository.toggleFavorite(id)
  })

  ipcMain.handle('clipboard:togglePin', async (_, id: string) => {
    return repository.togglePin(id)
  })

  ipcMain.handle('clipboard:pasteItem', async (_, id: string) => {
    const item = repository.getItemById(id)
    if (!item) return

    writeItemToClipboard(item.content, item.content_type)
    const previousApp = windowManager.getPreviousAppBundleId()
    windowManager.hide()

    // Defer use count update — not on the critical paste path
    process.nextTick(() => repository.incrementUseCount(id))

    // Reactivate previous app then simulate Cmd+V
    setTimeout(() => {
      if (previousApp) {
        exec(
          `osascript -e 'tell application id "${previousApp}" to activate'`,
          () => {
            setTimeout(() => {
              exec(
                `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
              )
            }, 20)
          }
        )
      } else {
        setTimeout(() => {
          exec(
            `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
          )
        }, 20)
      }
    }, 30)
  })

  ipcMain.handle('clipboard:updateTitle', async (_, id: string, title: string | null) => {
    return repository.updateItemTitle(id, title)
  })

  ipcMain.handle('clipboard:clearAll', async () => {
    return repository.clearAll()
  })

  ipcMain.handle('clipboard:getStarredCount', async () => {
    return repository.getStarredCount()
  })

  // Template IPC handlers
  ipcMain.handle('templates:getAll', async () => {
    return repository.getTemplates()
  })

  ipcMain.handle('templates:create', async (_, id: string, name: string, content: string, categoryId?: string) => {
    return repository.createTemplate(id, name, content, categoryId)
  })

  ipcMain.handle('templates:update', async (_, id: string, name: string, content: string) => {
    return repository.updateTemplate(id, name, content)
  })

  ipcMain.handle('templates:delete', async (_, id: string) => {
    return repository.deleteTemplate(id)
  })

  // Category IPC handlers
  ipcMain.handle('categories:getAll', async () => {
    return repository.getCategories()
  })

  ipcMain.handle('categories:create', async (_, id: string, name: string, color: string | null) => {
    return repository.createCategory(id, name, color)
  })

  ipcMain.handle('categories:delete', async (_, id: string) => {
    return repository.deleteCategory(id)
  })

  ipcMain.handle('clipboard:updateCategory', async (_, itemId: string, categoryId: string | null) => {
    return repository.updateItemCategory(itemId, categoryId)
  })

  // Settings IPC handlers
  // Tags IPC handlers
  ipcMain.handle('tags:list', async () => {
    return repository.listTagsWithCounts()
  })

  ipcMain.handle('tags:apply', async (_, itemId: string, slugs: string[]) => {
    return repository.applyTags(itemId, slugs)
  })

  ipcMain.handle('tags:remove', async (_, itemId: string, slug: string) => {
    return repository.removeTag(itemId, slug)
  })

  ipcMain.handle('tags:getItemSlugs', async (_, itemId: string) => {
    return repository.getItemTagSlugs(itemId)
  })

  ipcMain.handle('tags:rename', async (_, slug: string, nextName: string) => {
    return repository.renameTag(slug, nextName)
  })

  ipcMain.handle('tags:delete', async (_, slug: string) => {
    return repository.deleteTag(slug)
  })

  ipcMain.handle('tags:merge', async (_, sourceSlug: string, targetSlug: string) => {
    return repository.mergeTag(sourceSlug, targetSlug)
  })

  ipcMain.handle('tags:stats', async () => {
    return repository.getTagStats()
  })

  ipcMain.handle('tags:similar', async (_, name: string) => {
    return repository.getSimilarTags(name)
  })

  ipcMain.handle('settings:setLaunchAtLogin', async (_, enabled: boolean) => {
    app.setLoginItemSettings({ openAtLogin: enabled })
  })

  ipcMain.handle('settings:getLaunchAtLogin', async () => {
    return app.getLoginItemSettings().openAtLogin
  })

  ipcMain.handle('settings:setLanguage', async (_, lang: string) => {
    trayManager.setLanguage(lang)
    setApplicationMenu(lang)
  })

  ipcMain.handle('settings:setTheme', async (_, theme: string) => {
    // Broadcast to all renderer windows so their stores stay in sync
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send('settings:themeChanged', theme)
      }
    }
  })

  ipcMain.handle('settings:setAccentColor', async (_, color: string) => {
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send('settings:accentColorChanged', color)
      }
    }
  })

  ipcMain.handle('settings:setLayoutMode', async (_, mode: string) => {
    if (mode === 'center' || mode === 'side' || mode === 'bottom') {
      windowManager.setLayoutMode(mode)
      // Broadcast to all renderer windows so their stores stay in sync
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send('settings:layoutModeChanged', mode)
        }
      }
    }
  })

  ipcMain.handle('settings:setMaxItems', async (_, value: number) => {
    cleanupMaxItems = normalizeMaxItems(value)
    return cleanupMaxItems
  })

  ipcMain.handle('settings:openWindow', async (_, view: string) => {
    settingsWindowManager.open(view === 'onboarding' ? 'onboarding' : 'settings')
  })

  ipcMain.handle('sync:now', async () => {
    if (!syncService) {
      syncService = new iCloudSync()
      syncService.start()
    }
    syncService.syncNow()
  })

  // Content type counts
  ipcMain.handle('clipboard:getContentTypeCounts', async (_, options) => {
    return repository.getContentTypeCounts(options)
  })

  // Source app IPC handlers
  ipcMain.handle('sourceApps:getAll', async () => {
    return repository.getSourceApps()
  })

  ipcMain.handle('sourceApps:getIcon', async (_, bundleId: string) => {
    return getAppIcon(bundleId)
  })

  // Sequence paste IPC handlers
  ipcMain.handle('queue:add', async (_, item: { id: string; content: string; content_type: string }) => {
    shortcutManager.addToQueue(item)
    return shortcutManager.getQueueCount()
  })

  ipcMain.handle('queue:addMultiple', async (_, items: { id: string; content: string; content_type: string }[]) => {
    shortcutManager.addMultipleToQueue(items)
    return shortcutManager.getQueueCount()
  })

  ipcMain.handle('queue:clear', async () => {
    shortcutManager.clearQueue()
  })

  ipcMain.handle('queue:getCount', async () => {
    return shortcutManager.getQueueCount()
  })

  ipcMain.handle('queue:getItems', async () => {
    return shortcutManager.getQueueItems()
  })

  ipcMain.handle('shortcuts:update', async (_, config: {
    panelShortcut?: string
    sequencePaste?: string
    batchPaste?: string
    widgetToggle?: string
    widgetQuickPastePrefix?: string
    cycleLayout?: string
  }) => {
    shortcutManager.updateShortcuts(config)
    if (config.widgetQuickPastePrefix) {
      trayManager.setQuickPastePrefix(config.widgetQuickPastePrefix)
    }
  })

  // Widget state
  let widgetFollowFilter = false
  let currentPanelFilter: {
    contentType?: string
    leftFilter?: { type: string; slug?: string }
    sourceApp?: string
    sortBy?: string
  } = {}

  ipcMain.handle('widget:syncFilter', async (_, filter) => {
    currentPanelFilter = filter
    // Notify widget to refresh
    const widgetWin = widgetManager.getWindow()
    if (widgetWin && !widgetWin.isDestroyed()) {
      widgetWin.webContents.send('widget:filterChanged')
    }
  })

  ipcMain.handle('widget:setFollowFilter', async (_, value: boolean) => {
    widgetFollowFilter = value
    // Notify widget to refresh
    const widgetWin = widgetManager.getWindow()
    if (widgetWin && !widgetWin.isDestroyed()) {
      widgetWin.webContents.send('widget:filterChanged')
    }
  })

  ipcMain.handle('widget:getItems', async () => {
    if (widgetFollowFilter) {
      return repository.getItems({
        limit: 5,
        contentType: currentPanelFilter.contentType || undefined,
        leftFilter: currentPanelFilter.leftFilter as repository.LeftFilter | undefined,
        sourceApp: currentPanelFilter.sourceApp || undefined,
        sortBy: (currentPanelFilter.sortBy as 'recent' | 'usage') || 'recent'
      })
    }
    return repository.getItems({ limit: 5 })
  })

  // Widget IPC handlers
  ipcMain.handle('widget:setPinned', async (_, pinned: boolean) => {
    widgetManager.setPinned(pinned)
  })

  ipcMain.handle('widget:savePosition', async (_, x: number, y: number) => {
    widgetManager.savePosition(x, y)
  })

  ipcMain.handle('widget:toggle', async () => {
    widgetManager.toggle()
  })

  ipcMain.handle('widget:pasteItem', async (_, id: string) => {
    const item = repository.getItemById(id)
    if (!item) return

    writeItemToClipboard(item.content, item.content_type)

    // Hide widget if not pinned
    if (!widgetManager.getPinned()) {
      widgetManager.hide()
    }

    // Defer use count update
    process.nextTick(() => repository.incrementUseCount(id))

    // Get frontmost app and simulate paste
    exec(
      `osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true'`,
      (err, stdout) => {
        const previousApp = err ? null : stdout.trim()
        setTimeout(() => {
          if (previousApp) {
            exec(
              `osascript -e 'tell application id "${previousApp}" to activate'`,
              () => {
                setTimeout(() => {
                  exec(
                    `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
                  )
                }, 20)
              }
            )
          } else {
            setTimeout(() => {
              exec(
                `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
              )
            }, 20)
          }
        }, 30)
      }
    )
  })

  ipcMain.handle('queue:setSeparator', async (_, separator: string) => {
    shortcutManager.setBatchSeparator(separator)
  })

  ipcMain.handle('sync:start', async () => {
    if (!syncService) {
      syncService = new iCloudSync()
    }
    syncService.start()
  })

  ipcMain.handle('sync:stop', async () => {
    if (syncService) {
      syncService.stop()
    }
  })

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      windowManager.create()
    }
  })
})

app.on('window-all-closed', () => {
  // On macOS, keep the app running in the tray
})

app.on('will-quit', () => {
  shortcutManager.unregister()
  clipboardMonitor.stop()
  if (syncService) syncService.stop()
  const db = getDatabase()
  if (db) db.close()
})
