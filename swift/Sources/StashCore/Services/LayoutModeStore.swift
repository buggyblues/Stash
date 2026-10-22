import Foundation

/// Reads and writes the window settings file of the previous build.
///
/// The file lives next to the database (`window-settings.json`) and holds the
/// selected layout mode, so the choice carries over from the Electron build.
public enum LayoutModeStore {
    private struct Payload: Codable {
        var layoutMode: String
    }

    /// The stored layout mode, if there is a valid one.
    public static func load() -> LayoutMode? {
        guard let data = try? Data(contentsOf: AppPaths.windowSettingsURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let mode = LayoutMode(rawValue: payload.layoutMode)
        else { return nil }
        return mode
    }

    /// Stores the layout mode.
    public static func save(_ mode: LayoutMode) {
        let payload = Payload(layoutMode: mode.rawValue)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(
            at: AppPaths.supportDirectory,
            withIntermediateDirectories: true
        )
        try? data.write(to: AppPaths.windowSettingsURL)
    }
}
