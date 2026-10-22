import AppKit
import StashCore
import Foundation
import ServiceManagement

/// Registers the app so it starts automatically at login.
public enum LaunchAtLogin {
    private static let agentIdentifier = "com.zpaste.app"

    /// Whether the app is currently registered to launch at login.
    public static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return FileManager.default.fileExists(atPath: agentURL.path)
    }

    /// Enables or disables the login item.
    public static func setEnabled(_ enabled: Bool) {
        guard !AppPaths.isIsolated else { return }
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("[LaunchAtLogin] failed to update the login item: \(error.localizedDescription)")
            }
            return
        }

        if enabled {
            writeAgent()
        } else {
            try? FileManager.default.removeItem(at: agentURL)
        }
    }

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(agentIdentifier).plist")
    }

    private static func writeAgent() {
        let executable = Bundle.main.bundlePath + "/Contents/MacOS/Stash"
        let plist: [String: Any] = [
            "Label": agentIdentifier,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        ) else { return }
        try? FileManager.default.createDirectory(
            at: agentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: agentURL)
    }
}
