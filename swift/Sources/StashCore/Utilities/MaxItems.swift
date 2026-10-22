import Foundation

/// Limits for how many clipboard items Stash keeps around.
public enum MaxItems {
    /// `0` means "keep everything".
    public static let unlimited = 0
    public static let customMinimum = 500
    public static let presets = [500, 1000, 2000]
    public static let `default` = 2000

    /// Clamps a user supplied limit into a valid range.
    public static func normalize(_ value: Int) -> Int {
        if value <= unlimited { return unlimited }
        return max(value, customMinimum)
    }

    public static func isPreset(_ value: Int) -> Bool {
        presets.contains(value)
    }

    /// How many rows should be removed so the history fits into `maxItems`.
    public static func autoCleanupDeleteCount(count: Int, maxItems: Int) -> Int {
        let normalized = normalize(maxItems)
        if normalized == unlimited || count <= normalized { return 0 }
        return count - normalized
    }
}
