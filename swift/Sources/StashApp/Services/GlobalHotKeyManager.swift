import AppKit
import Carbon.HIToolbox
import Foundation
import StashCore

/// Registers system wide keyboard shortcuts.
///
/// The shortcuts use the same accelerator syntax as the previous build, e.g.
/// `Shift+CommandOrControl+V`, `CommandOrControl+;` or `Alt`.
///
/// Carbon delivers one event per press without requiring Input Monitoring.
public final class GlobalHotKeyManager {
    /// A registered shortcut.
    public struct Registration {
        public var identifier: String
        public var accelerator: String
        public var handler: () -> Void
    }

    private var registrations: [UInt32: Registration] = [:]
    private var hotKeys: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var localMonitor: Any?
    private var nextIdentifier: UInt32 = 1

    public init() {}

    deinit {
        unregisterAll()
        if let eventHandler { RemoveEventHandler(eventHandler) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    /// Registers a shortcut. Returns `false` when the accelerator could not be
    /// registered (for example because another app already owns it).
    @discardableResult
    public func register(accelerator: String, identifier: String, handler: @escaping () -> Void) -> Bool {
        guard let descriptor = HotKeyDescriptor(accelerator: accelerator)
        else { return false }

        let id = nextIdentifier
        nextIdentifier += 1

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            descriptor.keyCode,
            descriptor.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else { return false }

        registrations[id] = Registration(identifier: identifier, accelerator: accelerator, handler: handler)
        hotKeys[id] = hotKeyRef
        installHandlerIfNeeded()
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, !event.isARepeat else { return event }
                if (NSApp.keyWindow?.firstResponder as? NSView)?.identifier?.rawValue == "stash.shortcutCapture" { return event }
                let info = NativeKeyboard.info(for: event)
                for registration in self.registrations.sorted(by: { $0.key < $1.key }).map(\.value) {
                    if Shortcut.matches(info, registration.accelerator) {
                        self.fire(registration)
                        return nil
                    }
                }
                return event
            }
        }
        return true
    }

    /// Removes every registered shortcut.
    public func unregisterAll() {
        for (_, hotKey) in hotKeys {
            UnregisterEventHotKey(hotKey)
        }
        hotKeys.removeAll()
        registrations.removeAll()
    }

    private static let signature: OSType = {
        let value = "STSH"
        var signature: OSType = 0
        for byte in value.utf8 {
            signature = (signature << 8) | OSType(byte)
        }
        return signature
    }()

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handle(hotKeyID: hotKeyID)
                return noErr
            },
            1,
            &eventType,
            context,
            &eventHandler
        )
    }

    private func handle(hotKeyID: EventHotKeyID) {
        guard hotKeyID.signature == Self.signature else { return }
        guard let registration = registrations[hotKeyID.id] else { return }
        fire(registration)
    }

    /// Runs the action of a registered shortcut.
    private func fire(_ registration: Registration) {
        registration.handler()
    }

}
