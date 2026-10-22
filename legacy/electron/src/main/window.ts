import { BrowserWindow, screen, app } from 'electron'
import { join } from 'path'
import { is } from '@electron-toolkit/utils'
import { execSync } from 'child_process'
import { readFileSync, writeFileSync, existsSync } from 'fs'

export type LayoutMode = 'center' | 'side' | 'bottom'

export class WindowManager {
  private mainWindow: BrowserWindow | null = null
  private previousAppBundleId: string | null = null
  private layoutMode: LayoutMode
  private animationTimer: ReturnType<typeof setInterval> | null = null
  private static readonly SETTINGS_FILE = 'window-settings.json'

  constructor() {
    this.layoutMode = this.loadLayoutMode()
  }

  private getSettingsPath(): string {
    return join(app.getPath('userData'), WindowManager.SETTINGS_FILE)
  }

  private loadLayoutMode(): LayoutMode {
    try {
      const filePath = this.getSettingsPath()
      if (existsSync(filePath)) {
        const data = JSON.parse(readFileSync(filePath, 'utf-8'))
        if (data.layoutMode === 'center' || data.layoutMode === 'side' || data.layoutMode === 'bottom') {
          return data.layoutMode
        }
      }
    } catch {
      // ignore read errors
    }
    return 'center'
  }

  private saveLayoutMode(): void {
    try {
      writeFileSync(this.getSettingsPath(), JSON.stringify({ layoutMode: this.layoutMode }), 'utf-8')
    } catch {
      // ignore write errors
    }
  }

  getLayoutMode(): LayoutMode {
    return this.layoutMode
  }

  setLayoutMode(mode: LayoutMode): void {
    this.layoutMode = mode
    this.saveLayoutMode()
  }

  create(): BrowserWindow {
    if (this.mainWindow && !this.mainWindow.isDestroyed()) {
      return this.mainWindow
    }

    this.mainWindow = new BrowserWindow({
      width: 680,
      height: 480,
      show: false,
      frame: false,
      transparent: true,
      backgroundColor: '#00000000',
      resizable: true,
      minWidth: 400,
      minHeight: 300,
      alwaysOnTop: true,
      skipTaskbar: true,
      hasShadow: false,
      webPreferences: {
        preload: join(__dirname, '../preload/index.js'),
        sandbox: false
      }
    })

    this.mainWindow.on('blur', () => {
      this.hide()
    })

    if (is.dev && process.env['ELECTRON_RENDERER_URL']) {
      this.mainWindow.loadURL(process.env['ELECTRON_RENDERER_URL'])
    } else {
      this.mainWindow.loadFile(join(__dirname, '../renderer/index.html'))
    }

    return this.mainWindow
  }

  toggle(): void {
    if (!this.mainWindow || this.mainWindow.isDestroyed()) {
      this.create()
    }

    if (this.mainWindow!.isVisible()) {
      this.hide()
    } else {
      this.show()
    }
  }

  private safeSend(channel: string, ...args: unknown[]): void {
    try {
      if (this.mainWindow && !this.mainWindow.isDestroyed() && !this.mainWindow.webContents.isDestroyed()) {
        this.mainWindow.webContents.send(channel, ...args)
      }
    } catch {
      // frame not ready yet, ignore
    }
  }

  show(): void {
    const needsLoad = !this.mainWindow || this.mainWindow.isDestroyed()
    if (needsLoad) {
      this.create()
    }

    // Capture the frontmost app before we steal focus
    try {
      this.previousAppBundleId = execSync(
        `osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true'`,
        { encoding: 'utf-8' }
      ).trim()
    } catch {
      this.previousAppBundleId = null
    }

    const win = this.mainWindow!
    const cursorPoint = screen.getCursorScreenPoint()
    const display = screen.getDisplayNearestPoint(cursorPoint)
    const workArea = display.workArea

    // Calculate final bounds for each layout mode
    let finalBounds: { x: number; y: number; width: number; height: number }
    switch (this.layoutMode) {
      case 'side':
        finalBounds = {
          x: workArea.x + workArea.width - 420,
          y: workArea.y,
          width: 420,
          height: workArea.height
        }
        break
      case 'bottom':
        finalBounds = {
          x: workArea.x,
          y: workArea.y + workArea.height - 340,
          width: workArea.width,
          height: 340
        }
        break
      case 'center':
      default: {
        const w = 680, h = 480
        finalBounds = {
          x: Math.round(workArea.x + (workArea.width - w) / 2),
          y: Math.round(workArea.y + (workArea.height - h) / 2),
          width: w,
          height: h
        }
        break
      }
    }

    // Set initial position with slide offset
    const slideDistance = 12
    switch (this.layoutMode) {
      case 'side':
        win.setBounds({ ...finalBounds, x: finalBounds.x + slideDistance })
        break
      case 'bottom':
        win.setBounds({ ...finalBounds, y: finalBounds.y + slideDistance })
        break
      case 'center':
      default:
        win.setBounds({ ...finalBounds, y: finalBounds.y + slideDistance })
        break
    }

    // Clear any previous animation
    if (this.animationTimer) {
      clearInterval(this.animationTimer)
      this.animationTimer = null
    }

    win.setOpacity(0)
    win.show()
    win.focus()

    // Animate: fade in + slide to final position over ~150ms
    const totalSteps = 10
    const stepInterval = 16 // ~60fps
    let step = 0
    this.animationTimer = setInterval(() => {
      step++
      // ease-out cubic: 1 - (1-t)^3
      const t = step / totalSteps
      const eased = 1 - Math.pow(1 - t, 3)

      try {
        if (!win.isDestroyed()) {
          win.setOpacity(eased)

          // Slide to final position
          const currentBounds = win.getBounds()
          switch (this.layoutMode) {
            case 'side': {
              const targetX = Math.round(finalBounds.x + slideDistance * (1 - eased))
              win.setBounds({ ...currentBounds, x: targetX })
              break
            }
            case 'bottom': {
              const targetY = Math.round(finalBounds.y + slideDistance * (1 - eased))
              win.setBounds({ ...currentBounds, y: targetY })
              break
            }
            case 'center':
            default: {
              const targetY = Math.round(finalBounds.y + slideDistance * (1 - eased))
              win.setBounds({ ...currentBounds, y: targetY })
              break
            }
          }
        }
      } catch {
        // window may have been destroyed during animation
      }

      if (step >= totalSteps) {
        if (this.animationTimer) {
          clearInterval(this.animationTimer)
          this.animationTimer = null
        }
        // Ensure final state is exact
        try {
          if (!win.isDestroyed()) {
            win.setOpacity(1)
            win.setBounds(finalBounds)
          }
        } catch {
          // ignore
        }
      }
    }, stepInterval)

    if (needsLoad) {
      win.webContents.once('did-finish-load', () => {
        this.safeSend('panel:shown')
      })
    } else {
      this.safeSend('panel:shown')
    }
  }

  hide(): void {
    if (this.mainWindow && !this.mainWindow.isDestroyed()) {
      // Clear any show animation in progress
      if (this.animationTimer) {
        clearInterval(this.animationTimer)
        this.animationTimer = null
      }
      this.mainWindow.setOpacity(1) // reset to ensure clean state
      this.mainWindow.hide()
      this.safeSend('panel:hidden')
    }
  }

  getPreviousAppBundleId(): string | null {
    return this.previousAppBundleId
  }

  getWindow(): BrowserWindow | null {
    return this.mainWindow
  }
}
