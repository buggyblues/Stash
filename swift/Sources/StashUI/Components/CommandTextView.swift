import AppKit

/// A text view that reports ⌘Enter and Escape to the caller.
final class CommandTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onEscape: (() -> Void)?
    var focusWhenAttached = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard focusWhenAttached, let window else { return }
        focusWhenAttached = false
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        let characters = event.charactersIgnoringModifiers ?? ""

        if characters == "\r" || characters == "\n" {
            if event.modifierFlags.contains(.command) {
                onSubmit?()
                return
            }
        }
        if characters == "\u{1B}" {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}
