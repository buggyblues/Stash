import AppKit
import CoreGraphics
import Foundation

/// Writes clipboard content back to the system pasteboard and simulates a
/// ⌘V into the previously focused application.
public final class PasteService {
    public static let shared = PasteService()

    private init() {}

    /// The bundle identifier of the application that currently has focus.
    public var frontmostBundleIdentifier: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    /// Writes a clipboard item's content to the system pasteboard.
    ///
    /// Images are written as PNG data, everything else as plain text.
    @discardableResult
    public func write(content: String, contentType: String) -> Bool {
        let pasteboard = NSPasteboard.general

        if contentType == "image" {
            if let data = imageData(for: content) {
                pasteboard.clearContents()
                pasteboard.setData(data, forType: .png)
                return true
            }
            return false
        }

        pasteboard.clearContents()
        return pasteboard.setString(content, forType: .string)
    }

    /// Writes plain text to the system pasteboard.
    public func write(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Returns the PNG payload of an image item, either base64 encoded or
    /// stored as a file on disk.
    private func imageData(for content: String) -> Data? {
        let isFilePath = content.hasPrefix("/") || content.hasPrefix("~")
        if isFilePath {
            let path = content.hasPrefix("~")
                ? (content as NSString).expandingTildeInPath
                : content
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                return data
            }
            return nil
        }
        return Data(base64Encoded: content)
    }

    /// Simulates a ⌘V keystroke.
    public func simulatePaste(into bundleId: String? = nil, attempts: Int = 20) {
        if let bundleId, NSWorkspace.shared.frontmostApplication?.bundleIdentifier != bundleId {
            guard attempts > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.simulatePaste(into: bundleId, attempts: attempts - 1)
            }
            return
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    /// Brings the given application to the front.
    public func activate(bundleId: String) {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else {
            return
        }
        app.activate(options: [.activateIgnoringOtherApps])
    }
}
