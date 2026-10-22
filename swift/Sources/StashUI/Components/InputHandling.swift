import AppKit
import SwiftUI

/// Reports mouse clicks with their click count and modifier flags.
struct ClickCatcher: NSViewRepresentable {
    var onClick: (Int, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ClickCatcherView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ClickCatcherView)?.onClick = onClick
    }
}

/// The view that forwards mouse clicks.
final class ClickCatcherView: NSView {
    var onClick: ((Int, NSEvent.ModifierFlags) -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?(event.clickCount, event.modifierFlags)
    }
}

/// A monospaced text editor with a transparent background.
///
/// `TextEditor` only allows a transparent background from macOS 13 onwards, so
/// the editor is implemented with an `NSTextView` instead.
struct MonospacedTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .monospacedSystemFont(ofSize: 11, weight: .regular)
    var foregroundColor: NSColor = .labelColor
    var backgroundColor: NSColor = .clear
    var isEditable = true
    var focusOnAppear = false
    var onExit: (() -> Void)?
    /// Called for ⌘Enter, which saves the content.
    var onSubmit: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = CommandTextView()
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = font
        textView.textColor = foregroundColor
        textView.backgroundColor = backgroundColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.delegate = context.coordinator
        textView.focusWhenAttached = focusOnAppear
        textView.onSubmit = onSubmit
        textView.onEscape = onExit
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.textView = textView


        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.font = font
        textView.textColor = foregroundColor
        textView.backgroundColor = backgroundColor
        textView.isEditable = isEditable
        textView.onSubmit = onSubmit
        textView.onEscape = onExit
        context.coordinator.text = $text
        context.coordinator.onExit = onExit
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onExit: onExit)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onExit: (() -> Void)?
        weak var textView: CommandTextView?

        init(text: Binding<String>, onExit: (() -> Void)?) {
            self.text = text
            self.onExit = onExit
        }

        func textDidChange(_ notification: Notification) {
            text.wrappedValue = textView?.string ?? ""
        }


    }
}
