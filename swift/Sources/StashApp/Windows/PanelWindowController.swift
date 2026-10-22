import AppKit
import StashCore
import SwiftUI
import StashUI

/// A panel that can become the key window so the search field accepts typing.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// The borderless panel that shows the clipboard history.
public final class PanelWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel!
    private var hostingView: NSHostingView<AnyView>!
    private var animationTimer: Timer?

    private let settings: SettingsStore
    private var previousAppBundleId: String?
    private var theme: StashTheme

    /// Called whenever the panel becomes visible or hidden.
    public var onVisibilityChanged: ((Bool) -> Void)?

    public init(settings: SettingsStore) {
        self.settings = settings
        self.theme = StashTheme(resolved: settings.resolvedTheme, accentHex: settings.accentColor)
        super.init()
        create()
    }

    // MARK: - Creation

    private func create() {
        let panel = KeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
            styleMask: [.borderless, .fullSizeContentView],
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.identifier = WindowIdentifiers.panel
        panel.delegate = self
        panel.setFrameAutosaveName("")
        self.panel = panel

        let hosting = NSHostingView(rootView: AnyView(EmptyView()))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = NSView()
        panel.contentView?.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor)
        ])
        hostingView = hosting
    }

    /// Installs the SwiftUI content.
    public func setContent<V: View>(_ view: V) {
        hostingView.rootView = AnyView(ZoomContainer(identifier: WindowIdentifiers.panel) { view })
    }

    public var window: NSWindow? { panel }

    // MARK: - Visibility

    /// Shows the panel, animating it in.
    public func show() {
        // Remember the application that was focused before we take over.
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousAppBundleId = frontmost.bundleIdentifier
        }
        if panel.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let target = targetFrame()
        // The side layout slides in from the right, the other layouts from
        // the bottom.
        let slide = settings.layoutMode == .side
        panel.setFrame(
            slide ? target.offsetBy(dx: 12, dy: 0) : target.offsetBy(dx: 0, dy: 12),
            display: true
        )

        animationTimer?.invalidate()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrame(target, display: true)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            onVisibilityChanged?(true)
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            return
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        onVisibilityChanged?(true)
        // The panel needs the keyboard, so the app is activated and the panel
        // becomes its key window.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        var step = 0
        let totalSteps = 10
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            step += 1
            let progress = min(Double(step) / Double(totalSteps), 1)
            let eased = 1 - pow(1 - progress, 3)

            self.panel.alphaValue = eased
            var frame = self.panel.frame
            if slide {
                frame.origin.x = target.origin.x + 12 * (1 - eased)
            } else {
                frame.origin.y = target.origin.y + 12 * (1 - eased)
            }
            self.panel.setFrame(frame, display: true)

            if step >= totalSteps {
                self.animationTimer?.invalidate()
                self.animationTimer = nil
                self.panel.alphaValue = 1
                self.panel.setFrame(target, display: true)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    /// Hides the panel.
    public func hide() {
        animationTimer?.invalidate()
        animationTimer = nil
        panel.alphaValue = 1
        panel.orderOut(nil)
        onVisibilityChanged?(false)
    }

    public func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    public var isVisible: Bool { panel.isVisible }

    /// The bundle identifier of the application that was focused before the
    /// panel was shown.
    public var previousApp: String? { previousAppBundleId }

    // MARK: - Layout

    /// The frame the panel occupies for the current layout mode.
    public func targetFrame() -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return NSRect(x: 0, y: 0, width: 680, height: 480) }
        let workArea = screen.visibleFrame

        switch settings.layoutMode {
        case .side:
            let width: CGFloat = min(460, workArea.width - 24)
            return NSRect(
                x: workArea.maxX - width - 12,
                y: workArea.minY + 12,
                width: width,
                height: workArea.height - 24
            )
        case .bottom:
            let height: CGFloat = min(340, workArea.height - 24)
            return NSRect(
                x: workArea.minX + 12,
                y: workArea.minY + 12,
                width: workArea.width - 24,
                height: height
            )
        case .center:
            let width: CGFloat = min(1000, workArea.width - 48)
            let height: CGFloat = min(660, workArea.height - 48)
            return NSRect(
                x: round(workArea.midX - width / 2),
                y: round(workArea.midY - height / 2),
                width: width,
                height: height
            )
        }
    }

    /// Re-applies the layout, e.g. after the layout mode changed.
    public func applyLayout() {
        guard panel.isVisible else { return }
        panel.setFrame(targetFrame(), display: true)
    }

    // MARK: - Appearance

    public func updateTheme(_ theme: StashTheme) {
        self.theme = theme
        panel.backgroundColor = .clear
    }

    // MARK: - NSWindowDelegate

    public func windowDidResignKey(_ notification: Notification) {
        // The user switched to another application, so the panel closes.
        hide()
    }
}
