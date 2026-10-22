import AppKit
import StashCore
import SwiftUI
import StashUI

/// A borderless window that can still become the key window, so the text
/// fields inside it accept input.
final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// The separate settings window.
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public private(set) var window: NSWindow?
    private var hostingController: NSHostingController<AnyView>?
    private var requestedAppearance: NSAppearance?
    private var pendingContent = AnyView(EmptyView())

    /// Called when the settings window is closed.
    public var onClosed: (() -> Void)?
    /// The view the window currently shows.
    public enum Kind: String {
        case settings
        case onboarding
    }

    public override init() {
        super.init()
    }

    /// The view the window was opened with.
    private var currentKind: Kind = .settings

    /// Opens the window, creating it when necessary.
    public func open(_ view: Kind = .settings) {
        if let window {
            // The old build kept the view the window was loaded with.
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        currentKind = view

        let size = view == .onboarding
            ? NSSize(width: 860, height: 640)
            : NSSize(width: 760, height: 560)

        let window = KeyWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = view == .settings ? L10n.t("settings.title") : "Stash"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.appearance = requestedAppearance
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        window.hasShadow = true
        window.identifier = WindowIdentifiers.settings
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self

        // A hosting controller participates in native navigation and toolbar
        // integration; a bare hosting view in a custom container does not.
        let hosting = NSHostingController(rootView: pendingContent)
        if #available(macOS 13.0, *) { hosting.sizingOptions = [] }
        window.contentViewController = hosting
        window.identifier = WindowIdentifiers.settings
        window.contentMinSize = NSSize(width: 660, height: 440)
        window.setFrameAutosaveName("")
        window.setContentSize(size)
        hostingController = hosting
        self.window = window

        center(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Replaces the content of the window.
    public func setContent<V: View>(_ view: V) {
        pendingContent = AnyView(view)
        hostingController?.rootView = pendingContent
    }

    /// Apply before the first display, and whenever the app theme changes.
    /// Window chrome must not depend on a zero-size SwiftUI background view
    /// having attached to the correct NSWindow.
    public func updateAppearance(_ theme: ResolvedTheme) {
        requestedAppearance = NSAppearance(named: theme == .dark ? .darkAqua : .aqua)
        window?.appearance = requestedAppearance
    }

    public func close() {
        window?.close()
    }

    public var isVisible: Bool { window?.isVisible ?? false }

    private func center(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }
        let workArea = screen.visibleFrame
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(
            x: round(workArea.midX - size.width / 2),
            y: round(workArea.midY - size.height / 2)
        ))
    }

    // MARK: - NSWindowDelegate

    public func windowWillClose(_ notification: Notification) {
        window = nil
        hostingController = nil
        onClosed?()
    }
}

/// The floating desktop widget.
public final class WidgetWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var savedPosition: NSPoint?

    public override init() {
        super.init()
        // The window is created right away so that the content can be
        // installed before the widget is shown for the first time.
        create()
    }

    private func create() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 240),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = true
        panel.identifier = WindowIdentifiers.widget
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.delegate = self

        let hosting = NSHostingView(rootView: AnyView(EmptyView()))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        panel.contentView = container
        hostingView = hosting
        self.panel = panel
    }

    public func setContent<V: View>(_ view: V) {
        hostingView?.rootView = AnyView(view)
    }

    public func show() {
        if panel == nil { create() }
        guard let panel else { return }
        if let savedPosition {
            panel.setFrameOrigin(savedPosition)
        } else {
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
            if let screen {
                let workArea = screen.visibleFrame
                let size = panel.frame.size
                panel.setFrameOrigin(NSPoint(
                    x: round(workArea.maxX - size.width - 20),
                    y: round(workArea.minY + 20)
                ))
            }
        }
        panel.orderFrontRegardless()
    }

    public func hide() {
        panel?.orderOut(nil)
    }

    public func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    public var window: NSWindow? { panel }

    public var isVisible: Bool { panel?.isVisible ?? false }

    public func savePosition() {
        guard let panel else { return }
        savedPosition = panel.frame.origin
    }

    // MARK: - NSWindowDelegate

    /// Whether the widget stays visible when it loses the focus.
    public var isPinned = true

    public func windowDidResignKey(_ notification: Notification) {
        // The widget only hides automatically when it is not pinned.
        if !isPinned {
            hide()
        }
    }

    public func windowDidMove(_ notification: Notification) {
        savePosition()
    }
}
