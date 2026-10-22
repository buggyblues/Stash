import Foundation

/// The on-disk locations Stash uses.
///
/// The locations deliberately match the previous Electron build so that an
/// existing clipboard history keeps working after the migration.
public enum AppPaths {
    /// Optional isolated profile for development and acceptance testing.
    public static var isIsolated: Bool { ProcessInfo.processInfo.environment["STASH_PROFILE_DIRECTORY"] != nil }

    public static var settingsDefaults: UserDefaults {
        if isIsolated {
            return UserDefaults(suiteName: "com.zpaste.stash-qa")!
        }
        return .standard
    }

    /// `~/Library/Application Support/Stash`
    public static var supportDirectory: URL {
        if let path = ProcessInfo.processInfo.environment["STASH_PROFILE_DIRECTORY"], path.hasPrefix("/") {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Stash", isDirectory: true)
    }

    /// `~/Library/Application Support/Stash/data`
    public static var dataDirectory: URL {
        supportDirectory.appendingPathComponent("data", isDirectory: true)
    }

    /// `~/Library/Application Support/Stash/data/zpaste.db`
    public static var databaseURL: URL {
        dataDirectory.appendingPathComponent("zpaste.db")
    }

    /// `~/Library/Application Support/Stash/images`
    public static var imagesDirectory: URL {
        supportDirectory.appendingPathComponent("images", isDirectory: true)
    }

    /// `~/Library/Application Support/Stash/app-icons`
    public static var appIconsDirectory: URL {
        supportDirectory.appendingPathComponent("app-icons", isDirectory: true)
    }

    /// `~/Library/Application Support/Stash/window-settings.json`
    public static var windowSettingsURL: URL {
        supportDirectory.appendingPathComponent("window-settings.json")
    }

    /// `~/Library/Application Support/Stash/sync-state.json`
    public static var syncStateURL: URL {
        supportDirectory.appendingPathComponent("sync-state.json")
    }

    /// `~/Library/Application Support/Stash/.zpaste-device-id`
    public static var deviceIdURL: URL {
        supportDirectory.appendingPathComponent(".zpaste-device-id")
    }

    /// The iCloud Drive folder used for sync.
    public static var iCloudSyncDirectory: URL {
        if isIsolated { return supportDirectory.appendingPathComponent("test-sync", isDirectory: true) }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/ZPaste", isDirectory: true)
    }

    /// Creates every directory Stash writes into.
    @discardableResult
    public static func ensureDirectories() -> Bool {
        let manager = FileManager.default
        var success = true
        for directory in [supportDirectory, dataDirectory, imagesDirectory, appIconsDirectory] {
            do {
                try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                success = false
            }
        }
        return success
    }
}
