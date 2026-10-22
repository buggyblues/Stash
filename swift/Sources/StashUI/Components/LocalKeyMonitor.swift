import AppKit
import SwiftUI

/// Installs a local key event monitor and forwards the events to a handler.
///
/// The handler returns `true` when the event was consumed.
public struct LocalKeyMonitor: NSViewRepresentable {
    private let onKey: (NSEvent) -> Bool

    public init(onKey: @escaping (NSEvent) -> Bool) {
        self.onKey = onKey
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.view = view
        context.coordinator.onKey = onKey
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { event in
            if context.coordinator.onKey?(event) == true { return nil }
            return event
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onKey = onKey
    }

    public static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
            coordinator.monitor = nil
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator {
        var onKey: ((NSEvent) -> Bool)?
        var monitor: Any?
        weak var view: NSView?
    }
}

/// Reports whether the key window's first responder is a text input.
public enum InputFocus {
    public static var isTextInputFocused: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        if let view = responder as? NSView {
            return view is NSTextView || view is NSTextField
                || (view as? NSTextField)?.isEditable == true
        }
        return false
    }

    /// Restores focus to an open quick editor when the panel is shown again.
    public static func focusEditor() {
        func find(in view: NSView) -> CommandTextView? {
            if let editor = view as? CommandTextView, editor.isEditable { return editor }
            for child in view.subviews {
                if let editor = find(in: child) { return editor }
            }
            return nil
        }
        guard let window = NSApp.keyWindow, let content = window.contentView,
              let editor = find(in: content) else { return }
        window.makeFirstResponder(editor)
    }

    /// Moves the focus into the search field.
    public static func focusSearchField() {
        guard let window = NSApp.keyWindow else { return }
        window.makeFirstResponder(window.firstResponder)
    }
}
