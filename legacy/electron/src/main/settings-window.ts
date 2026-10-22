import { BrowserWindow, screen } from 'electron'
import { join } from 'path'
import { is } from '@electron-toolkit/utils'

export class SettingsWindowManager {
  private window: BrowserWindow | null = null
  private closedCallback: (() => void) | null = null

  onClosed(callback: () => void): void {
    this.closedCallback = callback
  }

  open(view: 'settings' | 'onboarding' = 'settings'): void {
    if (this.window && !this.window.isDestroyed()) {
      this.window.focus()
      return
    }

    const cursorPoint = screen.getCursorScreenPoint()
    const display = screen.getDisplayNearestPoint(cursorPoint)
    const { x, y, width, height } = display.workArea

    const winWidth = view === 'onboarding' ? 860 : 680
    const winHeight = view === 'onboarding' ? 640 : 520

    this.window = new BrowserWindow({
      width: winWidth,
      height: winHeight,
      show: false,
      frame: false,
      transparent: true,
      backgroundColor: '#00000000',
      resizable: true,
      minWidth: 500,
      minHeight: 400,
      alwaysOnTop: true,
      hasShadow: false,
      webPreferences: {
        preload: join(__dirname, '../preload/index.js'),
        sandbox: false
      }
    })

    this.window.setPosition(
      Math.round(x + (width - winWidth) / 2),
      Math.round(y + (height - winHeight) / 2)
    )

    if (is.dev && process.env['ELECTRON_RENDERER_URL']) {
      this.window.loadURL(
        process.env['ELECTRON_RENDERER_URL'] + `/settings.html?view=${view}`
      )
    } else {
      this.window.loadFile(join(__dirname, '../renderer/settings.html'), {
        query: { view }
      })
    }

    this.window.once('ready-to-show', () => {
      this.window?.show()
    })

    this.window.on('closed', () => {
      this.window = null
      this.closedCallback?.()
    })
  }

  getWindow(): BrowserWindow | null {
    return this.window
  }
}
