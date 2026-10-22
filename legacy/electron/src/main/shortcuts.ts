import { globalShortcut, clipboard, BrowserWindow } from 'electron'
import { exec } from 'child_process'
import { WindowManager } from './window'
import { WidgetWindowManager } from './widget'
import * as repository from './database/repository'
import { writeItemToClipboard } from './clipboard/paste-utils'
import { cycleLayoutMode } from '../shared/layout-mode'

interface QueueItem {
  id: string
  content: string
  content_type: string
}

export class ShortcutManager {
  private windowManager: WindowManager
  private widgetManager: WidgetWindowManager | null = null
  private sequenceQueue: QueueItem[] = []
  private queueIndex = 0
  private widgetToggleShortcut = 'Alt+W'
  private widgetQuickPastePrefix = 'Alt'
  private cycleLayoutShortcut = 'CommandOrControl+J'

  constructor(windowManager: WindowManager) {
    this.windowManager = windowManager
  }

  setWidgetManager(widgetManager: WidgetWindowManager): void {
    this.widgetManager = widgetManager
  }

  register(): void {
    globalShortcut.register('Shift+CommandOrControl+V', () => {
      this.windowManager.show()
    })

    this.registerSequencePaste('CommandOrControl+;')
    this.registerBatchPaste("CommandOrControl+'")
    this.registerWidgetShortcuts()
    this.registerCycleLayout()
  }

  private registerCycleLayout(): void {
    try {
      globalShortcut.register(this.cycleLayoutShortcut, () => {
        const current = this.windowManager.getLayoutMode()
        const next = cycleLayoutMode(current)
        this.windowManager.setLayoutMode(next)
        for (const win of BrowserWindow.getAllWindows()) {
          if (!win.isDestroyed()) {
            win.webContents.send('settings:layoutModeChanged', next)
          }
        }
        // Re-show with new layout if panel is visible
        const mainWin = this.windowManager.getWindow()
        if (mainWin && !mainWin.isDestroyed() && mainWin.isVisible()) {
          this.windowManager.show()
        }
      })
    } catch {
      // ignore if shortcut registration fails
    }
  }

  private registerWidgetShortcuts(): void {
    // Widget toggle
    try {
      globalShortcut.register(this.widgetToggleShortcut, () => {
        this.widgetManager?.toggle()
      })
    } catch {
      // ignore if shortcut registration fails
    }

    // Widget quick paste: prefix + 1~5
    for (let i = 1; i <= 5; i++) {
      const accelerator = `${this.widgetQuickPastePrefix}+${i}`
      try {
        globalShortcut.register(accelerator, () => {
          this.quickPasteByIndex(i - 1)
        })
      } catch {
        // ignore
      }
    }
  }

  private quickPasteByIndex(index: number): void {
    const items = repository.getItems({ limit: 5 })
    if (index >= items.length) return

    const item = items[index]
    writeItemToClipboard(item.content, item.content_type)
    process.nextTick(() => repository.incrementUseCount(item.id))

    // Get frontmost app before paste
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
            exec(
              `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
            )
          }
        }, 30)
      }
    )
  }

  private registerSequencePaste(accelerator: string): void {
    globalShortcut.register(accelerator, () => {
      if (this.sequenceQueue.length === 0 || this.queueIndex >= this.sequenceQueue.length) {
        this.clearQueue()
        this.notifyRenderer('queue:finished', null)
        return
      }

      const item = this.sequenceQueue[this.queueIndex]
      writeItemToClipboard(item.content, item.content_type)
      this.queueIndex++

      this.notifyRenderer('queue:pasted', {
        index: this.queueIndex,
        total: this.sequenceQueue.length
      })

      setTimeout(() => {
        exec(
          `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
        )
      }, 100)

      if (this.queueIndex >= this.sequenceQueue.length) {
        this.clearQueue()
        this.notifyRenderer('queue:finished', null)
      }
    })
  }

  private registerBatchPaste(accelerator: string): void {
    globalShortcut.register(accelerator, () => {
      if (this.sequenceQueue.length === 0) return

      const separator = this.getBatchSeparator()
      const combined = this.sequenceQueue.map((i) => i.content).join(separator)
      clipboard.writeText(combined)

      this.notifyRenderer('queue:batch-pasted', { count: this.sequenceQueue.length })

      setTimeout(() => {
        exec(
          `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
        )
      }, 100)

      this.clearQueue()
      this.notifyRenderer('queue:finished', null)
    })
  }

  private batchSeparator = '\n'

  setBatchSeparator(separator: string): void {
    this.batchSeparator = separator
  }

  private getBatchSeparator(): string {
    return this.batchSeparator
  }

  addToQueue(item: QueueItem): void {
    const resolved = this.resolveQueueItem(item.id)
    if (!resolved || this.sequenceQueue.some((q) => q.id === resolved.id)) return
    this.sequenceQueue.push(resolved)
    this.notifyRenderer('queue:updated', { count: this.sequenceQueue.length })
  }

  addMultipleToQueue(items: QueueItem[]): void {
    const existingIds = new Set(this.sequenceQueue.map((q) => q.id))
    const newItems = items
      .map((item) => this.resolveQueueItem(item.id))
      .filter((item): item is QueueItem => !!item && !existingIds.has(item.id))
    if (newItems.length === 0) return
    this.sequenceQueue.push(...newItems)
    this.notifyRenderer('queue:updated', { count: this.sequenceQueue.length })
  }

  private resolveQueueItem(id: string): QueueItem | null {
    const item = repository.getItemById(id)
    if (!item) return null
    return {
      id: item.id,
      content: item.content,
      content_type: item.content_type
    }
  }

  clearQueue(): void {
    this.sequenceQueue = []
    this.queueIndex = 0
    this.notifyRenderer('queue:updated', { count: 0 })
  }

  getQueueCount(): number {
    return this.sequenceQueue.length
  }

  getQueueItems(): QueueItem[] {
    return [...this.sequenceQueue]
  }

  updateShortcuts(config: {
    panelShortcut?: string
    sequencePaste?: string
    batchPaste?: string
    widgetToggle?: string
    widgetQuickPastePrefix?: string
    cycleLayout?: string
  }): void {
    globalShortcut.unregisterAll()

    if (config.widgetToggle) this.widgetToggleShortcut = config.widgetToggle
    if (config.widgetQuickPastePrefix) this.widgetQuickPastePrefix = config.widgetQuickPastePrefix
    if (config.cycleLayout) this.cycleLayoutShortcut = config.cycleLayout

    globalShortcut.register(config.panelShortcut || 'Shift+CommandOrControl+V', () => {
      this.windowManager.show()
    })

    this.registerSequencePaste(config.sequencePaste || 'CommandOrControl+;')
    this.registerBatchPaste(config.batchPaste || "CommandOrControl+'")
    this.registerWidgetShortcuts()
    this.registerCycleLayout()
  }

  private notifyRenderer(channel: string, data: unknown): void {
    const win = this.windowManager.getWindow()
    if (win && !win.isDestroyed()) {
      win.webContents.send(channel, data)
    }
  }

  unregister(): void {
    globalShortcut.unregisterAll()
  }
}
