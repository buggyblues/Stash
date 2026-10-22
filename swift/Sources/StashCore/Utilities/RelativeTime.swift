import Foundation

/// Formats a timestamp as a short, relative age.
public enum RelativeTime {
    /// The compact age shown on clipboard items.
    ///
    /// - under a minute → "just now"
    /// - under an hour  → "5m"
    /// - under a day    → "3h"
    /// - otherwise      → "7d"
    public static func format(timestamp: Int64, now: Date = Date()) -> String {
        let milliseconds = now.timeIntervalSince1970 * 1000 - Double(timestamp)
        let minutes = Int(milliseconds / 60_000)
        let hours = Int(milliseconds / 3_600_000)
        let days = Int(milliseconds / 86_400_000)

        if minutes < 1 { return Localization.shared.t("time.justNow") }
        if minutes < 60 { return Localization.shared.t("time.minutesAgo", ["count": String(minutes)]) }
        if hours < 24 { return Localization.shared.t("time.hoursAgo", ["count": String(hours)]) }
        return Localization.shared.t("time.daysAgo", ["count": String(days)])
    }

    /// The age shown in the preview panel.
    public static func useCount(_ count: Int) -> String {
        Localization.shared.t("preview.useCount", ["count": String(count)])
    }
}
