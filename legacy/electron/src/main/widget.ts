import { BrowserWindow, screen } from 'electron'
import { join } from 'path'
import { is } from '@electron-toolkit/utils'

export class WidgetWindowManager {
  private widgetWindow: BrowserWindow | null = null
  private isPinned = true
  private savedPosition: { x: number; y: number } | null = null

  create(): BrowserWindow {
    if (this.widgetWindow && !this.widgetWindow.isDestroyed()) {
      return this.widgetWindow
    }

    this.widgetWindow = new BrowserWindow({
      width: 280,
      height: 240,
      show: false,
      frame: false,
      transparent: true,
      backgroundColor: '#00000000',
      resizable: false,
      alwaysOnTop: true,
      skipTaskbar: true,
      hasShadow: false,
      webPreferences: {
        preload: join(__dirname, '../preload/index.js'),
        sandbox: false
      }
    })

    this.widgetWindow.on('blur', () => {
      if (!this.isPinned) {
        this.hide()
      }
    })

    this.widgetWindow.on('moved', () => {
      if (this.widgetWindow && !this.widgetWindow.isDestroyed()) {
        const [x, y] = this.widgetWindow.getPosition()
        this.savedPosition = { x, y }
      }
    })

    if (is.dev && process.env['ELECTRON_RENDERER_URL']) {
      this.widgetWindow.loadURL(process.env['ELECTRON_RENDERER_URL'] + '/widget.html')
    } else {
      this.widgetWindow.loadFile(join(__dirname, '../renderer/widget.html'))
    }

    return this.widgetWindow
  }

  toggle(): void {
    if (!this.widgetWindow || this.widgetWindow.isDestroyed()) {
      this.create()
    }
    if (this.widgetWindow!.isVisible()) {
      this.hide()
    } else {
      this.show()
    }
  }

  show(): void {
    if (!this.widgetWindow || this.widgetWindow.isDestroyed()) {
      this.create()
    }
    const win = this.widgetWindow!
    if (this.savedPosition) {
      win.setPosition(this.savedPosition.x, this.savedPosition.y)
    } else {
      const cursorPoint = screen.getCursorScreenPoint()
      const display = screen.getDisplayNearestPoint(cursorPoint)
      const { x, y, width, height } = display.workArea
      const winBounds = win.getBounds()
      win.setPosition(
        Math.round(x + width - winBounds.width - 20),
        Math.round(y + height - winBounds.height - 20)
      )
    }
    win.show()
    win.webContents.send('widget:shown')
  }

  hide(): void {
    if (this.widgetWindow && !this.widgetWindow.isDestroyed()) {
      this.widgetWindow.hide()
    }
  }

  setPinned(pinned: boolean): void {
    this.isPinned = pinned
    if (this.widgetWindow && !this.widgetWindow.isDestroyed()) {
      this.widgetWindow.webContents.send('widget:pinnedChanged', pinned)
    }
  }

  getPinned(): boolean {
    return this.isPinned
  }

  savePosition(x: number, y: number): void {
    this.savedPosition = { x, y }
  }

  getWindow(): BrowserWindow | null {
    return this.widgetWindow
  }

  notifyNewItem(item: unknown): void {
    if (this.widgetWindow && !this.widgetWindow.isDestroyed() && this.widgetWindow.isVisible()) {
      this.widgetWindow.webContents.send('clipboard:newItem', item)
    }
  }
}
