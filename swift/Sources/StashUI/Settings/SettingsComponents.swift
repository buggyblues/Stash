import AppKit
import StashCore
import SwiftUI

/// Captures a key press while it is the first responder.
struct KeyCaptureView: NSViewRepresentable {
    var isActive: Bool
    var onKey: (KeyEventInfo) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureNSView()
        view.identifier = NSUserInterfaceItemIdentifier("stash.shortcutCapture")
        view.onKey = onKey
        context.coordinator.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? KeyCaptureNSView else { return }
        view.onKey = onKey
        if view.isCapturing != isActive {
            view.isCapturing = isActive
        }
        if isActive {
            view.updateFirstResponder()
        } else {
            view.resignCapture()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var view: KeyCaptureNSView?
    }
}

/// The view that receives the key events while recording a shortcut.
final class KeyCaptureNSView: NSView {
    var onKey: ((KeyEventInfo) -> Void)?
    var isCapturing = false
    private var pendingModifier: KeyEventInfo?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateFirstResponder()
    }

    func updateFirstResponder() {
        guard isCapturing, let window else { return }
        window.makeFirstResponder(self)
    }

    /// Gives up the first responder role.
    func resignCapture() {
        guard let window, window.firstResponder === self else { return }
        window.makeFirstResponder(nil)
    }

    override func becomeFirstResponder() -> Bool { true }

    override func resignFirstResponder() -> Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isCapturing, let onKey else { return }
        pendingModifier = nil
        onKey(Self.info(for: event))
    }

    /// A lone modifier is delivered as a flags changed event, so it has to be
    /// handled as well to record a shortcut like "Alt".
    override func flagsChanged(with event: NSEvent) {
        guard isCapturing, let onKey else { return }
        let info = Self.info(for: event)
        if !info.metaKey && !info.ctrlKey && !info.shiftKey && !info.altKey {
            if let pendingModifier { onKey(pendingModifier) }
            pendingModifier = nil
        } else {
            pendingModifier = info.key.isEmpty ? nil : info
        }
    }

    static func info(for event: NSEvent) -> KeyEventInfo {
        NativeKeyboard.info(for: event)
    }

}

/// The badge that shows a shortcut.
struct ShortcutBadge: View {
    let shortcut: String
    let theme: StashTheme
    var onClick: (() -> Void)?

    var body: some View {
        if let onClick {
            Button(action: onClick) {
                text
            }
            .buttonStyle(.plain)
        } else {
            text
        }
    }

    private var text: some View {
        Text(Shortcut.display(shortcut))
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(theme.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(theme.muted.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(theme.border.opacity(0.6), lineWidth: 0.8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(theme.subtleSpecularHighlight, lineWidth: 0.5)
            )
    }
}

/// A grouped card container for settings rows (macOS Inset Grouped style).
struct SettingsGroupCard<Content: View>: View {
    let theme: StashTheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.cardElevated.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.border, lineWidth: 0.5)
        )
        .padding(.bottom, 16)
    }
}

/// The button that records a new shortcut.
struct ShortcutRecorder: View {
    @Binding var shortcut: String
    let theme: StashTheme
    var isGlobal = false

    @State private var isRecording = false

    var body: some View {
        ZStack {
            if isRecording {
                Text(L10n.t("settings.shortcuts.recording"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.accentForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(theme.accentColor)
                    )
                    .overlay(
                        KeyCaptureView(isActive: true) { info in
                            handle(info)
                        }
                        .frame(width: 1, height: 1)
                        .opacity(0.001)
                )
            } else {
                ShortcutBadge(shortcut: shortcut, theme: theme) {
                    isRecording = true
                }
            }
        }
        .onDisappear {
            isRecording = false
            if NSApp.keyWindow?.firstResponder is KeyCaptureNSView {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }

    private func handle(_ info: KeyEventInfo) {
        if info.key == "Escape" {
            isRecording = false
            resignFirstResponder()
            return
        }
        guard let definition = Shortcut.definition(from: info) else { return }
        if isGlobal {
            let parsed = Shortcut.parse(definition)
            guard HotKeyDescriptor(accelerator: definition) != nil,
                  parsed.usesCommand || parsed.usesControl || parsed.usesAlt else { return }
        }
        resignFirstResponder()
        shortcut = definition
        isRecording = false
    }

    private func resignFirstResponder() {
        guard let window = NSApp.keyWindow else { return }
        if window.firstResponder is KeyCaptureNSView {
            window.makeFirstResponder(nil)
        }
    }
}

/// A labelled row with a control on the trailing side.
struct SettingsRow<Control: View>: View {
    let title: String
    var description: String?
    let theme: StashTheme
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2.5) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(theme.foreground)
                if let description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(theme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// The title of a settings section.
struct SettingsSectionTitle: View {
    let title: String
    let theme: StashTheme

    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(theme.foreground)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
    }
}

/// A small toggle switch styled for the app.
struct AppToggle: View {
    @Binding var isOn: Bool
    let theme: StashTheme

    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
    }
}

/// A styled drop down.
struct AppPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(value: T, label: String)]
    let theme: StashTheme
    var width: CGFloat = 160

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: width)
    }
}

/// A styled push button.
struct AppButton: View {
    let title: String
    var isDestructive = false
    var isProminent = false
    var isEnabled = true
    let theme: StashTheme
    var action: () -> Void

    init(
        title: String,
        theme: StashTheme,
        isDestructive: Bool = false,
        isProminent: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.theme = theme
        self.isDestructive = isDestructive
        self.isProminent = isProminent
        self.isEnabled = isEnabled
        self.action = action
    }

    @ViewBuilder var body: some View {
        if isProminent {
            Button(title, action: action)
                .buttonStyle(.borderedProminent)
                .tint(theme.accentColor)
                .disabled(!isEnabled)
        } else {
            Button(role: isDestructive ? .destructive : nil, action: action) {
                Text(title)
            }
            .buttonStyle(.bordered)
            .disabled(!isEnabled)
        }
    }
}
