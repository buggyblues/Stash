import { Tray, Menu, nativeImage, app, clipboard } from 'electron'
import { execSync } from 'child_process'
import { WindowManager } from './window'
import * as repository from './database/repository'
import { normalizeDesktopLanguage, translateDesktop } from './localization'

export class TrayManager {
  private tray: Tray | null = null
  private windowManager: WindowManager
  private language = normalizeDesktopLanguage(app.getLocale())
  private quickPastePrefix: string = 'Alt'

  constructor(windowManager: WindowManager) {
    this.windowManager = windowManager
  }

  private getLabel(key: string): string {
    return translateDesktop(`tray.${key}`, this.language)
  }

  private formatPrefixSymbol(): string {
    switch (this.quickPastePrefix) {
      case 'Alt': return '⌥'
      case 'Control': return '⌃'
      case 'CommandOrControl': return '⌘'
      default: return '⌥'
    }
  }

  private buildMenu(): void {
    if (!this.tray) return

    const recentItems = repository.getItems({ limit: 5 })
    const prefixSymbol = this.formatPrefixSymbol()

    const recentMenuItems = recentItems.map((item, index) => {
      const preview = (item.preview || item.content || '').replace(/\n/g, ' ').slice(0, 40)
      return {
        label: `${prefixSymbol}${index + 1}  ${preview}`,
        click: (): void => {
          repository.incrementUseCount(item.id)
          clipboard.writeText(item.content)
          setTimeout(() => {
            try {
              execSync(
                `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
              )
            } catch {
              // ignore
            }
          }, 100)
        }
      }
    })

    const template: Electron.MenuItemConstructorOptions[] = []

    if (recentMenuItems.length > 0) {
      template.push(
        { label: this.getLabel('recentItems'), enabled: false },
        ...recentMenuItems,
        { type: 'separator' }
      )
    }

    template.push(
      {
        label: this.getLabel('openPanel'),
        accelerator: 'Shift+CommandOrControl+V',
        click: () => this.windowManager.toggle()
      },
      { type: 'separator' },
      {
        label: this.getLabel('launchAtLogin'),
        type: 'checkbox',
        checked: app.getLoginItemSettings().openAtLogin,
        click: (menuItem) => {
          app.setLoginItemSettings({ openAtLogin: menuItem.checked })
        }
      },
      { type: 'separator' },
      {
        label: this.getLabel('quit'),
        click: () => app.quit()
      }
    )

    const contextMenu = Menu.buildFromTemplate(template)
    this.tray.setContextMenu(contextMenu)
  }

  create(): void {
    const icon16 =
      'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAEKADAAQAAAABAAAAEAAAAAA0VXHyAAABlUlEQVQ4EY2Su0oDQRSGszeEGFi0EIl2FnaChfgCViKk8yH0JdJYJdgLQipTRLGJNj6BYEQUiUoacylCyLokYTfZ6/gP2QmTnfUyMJwzM+f758w5I6USRqfTWc9kMpuapi34vi8lhPR0XX8Q9mu1Wtq27QIgg/wycH4pwPl8XgV8wXEh/KRJgiA4EgT6/X7uPzBi3jCXBQHLskqRAH9rtDU1YRh+wNvmYZktZFleY35kKXWLdO9gTdd1i6Zp7kiS9BSLmy7H43GJEhg0A4Lb7lmg4ziPnufVXXdC357UlVRqOBweUJAbH6PRaKXVamUh8Mn2Pc85YcJztlKpKAjku0DQrn3DMA4jOMos8NGt3TmYLZ673UWkegqgiyfYsNlGo7GBOri8CNYFxgi2Wq2m8ZwihHrIqIzalAFMIMC6Q+tzJYB0o91ubwF6iW6Lm5kABM8EgWazuQS4zqXKgLiltckJAoPB4PgPmGV0DUcTBPDWGxbxg7WQ+vkXIToPzz4FiranquoqDgkfQH2AjqIor/iF7/Gzbw9EPswoyjiQAAAAAElFTkSuQmCC'
    const icon32 =
      'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAIKADAAQAAAABAAAAIAAAAACshmLzAAAEOElEQVRYCa1XS2gTQRjubpJNXxFp+rxYo0U9CHrypkR8IIhCFREPpR489GBBBMGDh570UETRk3oQPPSQCgUfeNBLKyKooFhseyj0kD7StDbJtkmaJtn1+zc7cXeyj1iz0M7M//r++Wfmm4lQ94/f2NjYzlAo1LS1tSWSqyiKgl0Iv9+v5nI5TU92qUIhd/zIkZjR3msc2PUnJia6enp6rgQCgbM+n2+fx+Nphq0WWFVVQTCkoKpQ/BVArTKtqCjKJ/idscOxlM/Pzw9sbm5GKdL/fkjgtSWIlXBwcNC/vLz81ACqoL/NP4X81GKxeM8Ky1K2tLT0uDbgpaQVNPl8/oQlGC+cmZm5VCgUGP42Z22qlory/5ibm6vnsSrGw8PDTbIs/9LRawJOsTChixVgVoLp6elzpaXWUqhJAlj7J1ZYJKs4hsFg8BQ7YXZOVcq144fSR8ABN+x8NDIxKiVJOmgcu/QJhJ1zMmVjarMAvwvwPvBClpRWH18BLxxarQw5mQaKRVqHHPEFIib6cvhbA/A4yv4Ak/miSf/hnyeVSn3XVt/5zOcBMJTNZncnk8m9Gxsb9zEugp7fr6ysXBsaGnLf7XZJIYHXLgkQobzg/dPp9Fvyg04B/88kEonBX5GIxNu5juPx+B23BHCk+vlA0Wj0tu5XbkDh7xcXF7t5W+O4YhOura29omrCyLi5jD51QNhvEmAg+aQ9ugzXEV1Jqorb8GRbW+u7WCwW4u2dxsL6+vqoQxWI1Vax9jiu2idMTk72Yv1lsw/xf+kOgO4jKtHoBGrSgTIPgLd/mwOaqRXL8EZ3EpOp5Dd721ISmUzmlgmEOVsJQ6EQbaIBRSnmobdcChy977qvkt/Ks75FuJK73y9dR8ydvEHFHmAG7e3to6mUfBXlTkBGUUyJYMZlUBzDb8zPplVF0bNLapTCvN42ATJsaWkZWV1dDWMN6WgWIdISQT+LV9EPFiwry1+xcZmeiStan+g7xgt5JuT1dR0dHT8hPJ9ILB/yeBr6AHwBu9uP90Lz7OxsDzmgtF7smSR0wYoABoEoiOyklKWuCZDl+Ph4KJMp9AYCdUe9Xm+QqLerq+sz6VANobu7GyUWif1w/Bw/RtmORkaliDfhTVDuCoCMH13T/Od2ddOb4KUxuGNffxM+N6C4AbjpiabvOoIalWCvRzUE1yqGfXLGiGHbn5qa6kW2mhOScJtZNXpiz2lMqskWlCnoKq3ySq4GmNnQ+vczDMcWb8LTmL0+8drMHvFGIpGIxxGYKePx2EN97Vn22221MCj9K3R2sPh8W8GE9fWNh3QjRr/bagGaRdmHFxYWLoM3ZB6YjU1EFA6Hvfjx2caU1bbEPsiSZkxvQvod+QFlf4Y3Yfm+sItFsyt/CCRk0unDcGyAsMxqYL9ynxljdpov0+GIKXgBybh2o52dnWlm59b+AdhVhFiMNK31AAAAAElFTkSuQmCC'

    const icon = nativeImage.createEmpty()
    icon.addRepresentation({
      scaleFactor: 1.0,
      buffer: Buffer.from(icon16, 'base64'),
      width: 16,
      height: 16
    })
    icon.addRepresentation({
      scaleFactor: 2.0,
      buffer: Buffer.from(icon32, 'base64'),
      width: 16,
      height: 16
    })

    this.tray = new Tray(icon)
    this.tray.setToolTip('Stash')

    this.buildMenu()

    this.tray.on('click', () => {
      this.windowManager.toggle()
    })

    this.tray.on('right-click', () => {
      this.buildMenu()
    })
  }

  setLanguage(lang: string): void {
    this.language = normalizeDesktopLanguage(lang)
    this.buildMenu()
  }

  setQuickPastePrefix(prefix: string): void {
    this.quickPastePrefix = prefix
    this.buildMenu()
  }

  refreshMenu(): void {
    this.buildMenu()
  }
}
