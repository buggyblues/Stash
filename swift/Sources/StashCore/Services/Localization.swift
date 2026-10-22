import Combine
import Foundation

/// The runtime translation service.
///
/// Mirrors the `i18next` behaviour of the previous implementation: keys are
/// looked up in the active bundle with a fallback to Simplified Chinese and
/// finally to the key itself, and `{{token}}` placeholders are interpolated.
public final class Localization: ObservableObject {
    public static let shared = Localization()

    /// Posted whenever the active language changes.
    public static let languageDidChange = Notification.Name("com.zpaste.app.languageDidChange")

    @Published public private(set) var language: AppLanguage

    private init() {
        language = .simplifiedChinese
    }

    /// The translation table for a language.
    public static func table(for language: AppLanguage) -> [String: String] {
        switch language {
        case .simplifiedChinese: return Locales.zhCN
        case .english: return Locales.english
        case .traditionalChinese: return Locales.zhTW
        }
    }

    /// Switches the active language and notifies observers.
    public func setLanguage(_ newLanguage: AppLanguage) {
        guard newLanguage != language else { return }
        language = newLanguage
        NotificationCenter.default.post(name: Self.languageDidChange, object: newLanguage)
    }

    /// Translates a key, interpolating `{{token}}` placeholders.
    public func t(_ key: String, _ params: [String: String] = [:]) -> String {
        let table = Self.table(for: language)
        let template = table[key] ?? Locales.zhCN[key] ?? key
        guard !params.isEmpty else { return template }
        return Self.interpolate(template, params)
    }

    /// Translates a key for a specific language, without changing the active one.
    public static func translate(
        _ key: String,
        language: AppLanguage,
        params: [String: String] = [:]
    ) -> String {
        let table = Self.table(for: language)
        let template = table[key] ?? Locales.zhCN[key] ?? key
        guard !params.isEmpty else { return template }
        return interpolate(template, params)
    }

    /// Replaces `{{token}}` placeholders with their values.
    public static func interpolate(_ template: String, _ params: [String: String]) -> String {
        var result = template
        for (token, value) in params {
            result = result.replacingOccurrences(of: "{{\(token)}}", with: value)
        }
        return result
    }
}
