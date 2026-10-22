import AppKit
import StashCore

/// The menu bar item.
public final class TrayController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let windowController: PanelWindowController
    private let repository: Repository

    private var language: AppLanguage = .simplifiedChinese
    private var quickPastePrefix = "Alt"
    private var menu: NSMenu?

    public var onPaste: ((ClipboardItem) -> Void)?
    public var onQuit: (() -> Void)?
    public var onLaunchAtLoginChanged: ((Bool) -> Void)?
    public var varLaunchAtLogin = false

    public init(windowController: PanelWindowController, repository: Repository) {
        self.windowController = windowController
        self.repository = repository
        super.init()
    }

    public func create() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Self.trayImage()
        statusItem.button?.image?.isTemplate = true
        // The button handles both mouse buttons: a left click toggles the
        // panel, a right click opens the menu.
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.statusItem = statusItem
    }

    /// Rebuilds the menu, e.g. after the language changed.
    public func refresh() {
        menu = buildMenu()
    }

    public func setLanguage(_ language: AppLanguage) {
        self.language = language
        refresh()
    }

    public func setQuickPastePrefix(_ prefix: String) {
        quickPastePrefix = prefix
        refresh()
    }

    private func buildMenu() -> NSMenu {
        // The login item state is read from the system, so the checkbox never
        // goes stale.
        varLaunchAtLogin = LaunchAtLogin.isEnabled
        let menu = NSMenu()
        menu.delegate = self

        let recentItems = (try? repository.getItems(options: GetItemsOptions(limit: 5))) ?? []
        let prefixSymbol = Self.prefixSymbol(quickPastePrefix)

        if !recentItems.isEmpty {
            let header = NSMenuItem(title: translate("tray.recentItems"), action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for (index, item) in recentItems.enumerated() {
                let preview = (item.preview ?? item.content)
                    .replacingOccurrences(of: "\n", with: " ")
                    .prefix(40)
                let entry = NSMenuItem(
                    title: "\(prefixSymbol)\(index + 1)  \(preview)",
                    action: #selector(pasteFromTray(_:)),
                    keyEquivalent: ""
                )
                entry.target = self
                entry.representedObject = item.id
                menu.addItem(entry)
            }
            menu.addItem(.separator())
        }

        let open = NSMenuItem(title: translate("tray.openPanel"), action: #selector(openPanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())

        let login = NSMenuItem(title: translate("tray.launchAtLogin"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = varLaunchAtLogin ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: translate("tray.quit"), action: #selector(quit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    // MARK: - Actions

    /// Handles a click on the menu bar icon.
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
        guard isRightClick else {
            windowController.toggle()
            return
        }

        // A right click opens the freshly built menu.
        let built = buildMenu()
        menu = built
        statusItem?.menu = built
        sender.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openPanel() {
        windowController.toggle()
    }

    @objc private func pasteFromTray(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let item = try? repository.getItemById(id)
        else { return }
        onPaste?(item)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        varLaunchAtLogin = sender.state == .on
        onLaunchAtLoginChanged?(varLaunchAtLogin)
        refresh()
    }

    @objc private func quit() {
        onQuit?()
    }

    // MARK: - Helpers

    private func translate(_ key: String) -> String {
        Localization.translate(key, language: language)
    }

    static func prefixSymbol(_ prefix: String) -> String {
        switch prefix {
        case "Alt": return "⌥"
        case "Control": return "⌃"
        case "CommandOrControl": return "⌘"
        default: return "⌥"
        }
    }

    /// A template image of a clipboard for the menu bar.
    static func trayImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        let board = NSBezierPath(roundedRect: NSRect(x: 4, y: 2.5, width: 10, height: 13), xRadius: 1.8, yRadius: 1.8)
        board.lineWidth = 1.2
        NSColor.labelColor.setStroke()
        board.stroke()

        let clip = NSBezierPath(roundedRect: NSRect(x: 6.5, y: 11.5, width: 5, height: 3.2), xRadius: 1, yRadius: 1)
        NSColor.labelColor.setFill()
        clip.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
