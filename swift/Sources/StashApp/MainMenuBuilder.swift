import AppKit
import StashCore
import StashUI

/// Builds the application menu.
///
/// The menu mirrors the one of the previous implementation: an application
/// menu with "Quit", an "Edit" menu with the standard editing commands and a
/// "View" menu with the zoom commands.
public enum MainMenuBuilder {
    public static func build(language: AppLanguage) -> NSMenu {
        let menu = NSMenu()

        // Application menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Stash")
        appMenu.addItem(
            withTitle: Localization.translate("tray.quit", language: language),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        menu.addItem(appMenuItem)

        // Standard responder-chain close command for the current window.
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: Localization.translate("menu.file", language: language))
        fileMenu.addItem(withTitle: Localization.translate("menu.closeWindow", language: language),
                         action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        menu.addItem(fileMenuItem)

        // Edit menu. An empty title makes AppKit use the localised system
        // title for the standard editing commands.
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: Localization.translate("menu.edit", language: language))
        editMenu.addItem(withTitle: Localization.translate("menu.undo", language: language), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: Localization.translate("menu.redo", language: language), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: Localization.translate("menu.cut", language: language), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: Localization.translate("menu.copy", language: language), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: Localization.translate("menu.paste", language: language), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: Localization.translate("menu.selectAll", language: language), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        menu.addItem(editMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: Localization.translate("menu.view", language: language))
        viewMenu.addItem(withTitle: Localization.translate("menu.zoomIn", language: language), action: #selector(ZoomMenuActions.zoomIn(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: Localization.translate("menu.zoomOut", language: language), action: #selector(ZoomMenuActions.zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: Localization.translate("menu.actualSize", language: language), action: #selector(ZoomMenuActions.resetZoom(_:)), keyEquivalent: "0")
        for item in viewMenu.items { item.target = ZoomMenuActions.shared }
        viewMenuItem.submenu = viewMenu
        menu.addItem(viewMenuItem)

        return menu
    }
}

/// Native equivalent of the Electron window zoom commands.
final class ZoomMenuActions: NSObject {
    static let shared = ZoomMenuActions()
    @objc func zoomIn(_ sender: Any?) { send(1) }
    @objc func zoomOut(_ sender: Any?) { send(-1) }
    @objc func resetZoom(_ sender: Any?) { send(0) }
    private func send(_ direction: Int) {
        guard let identifier = NSApp.keyWindow?.identifier else { return }
        NotificationCenter.default.post(name: .stashZoom, object: identifier, userInfo: ["direction": direction])
    }
}
