import Combine
import Foundation

/// Every user facing preference, persisted in `UserDefaults`.
///
/// The property names and defaults match the previous `settingsStore.ts`
/// implementation one to one.
public final class SettingsStore: ObservableObject {
    /// The key the previous build used inside `localStorage`.
    public static let storageKey = "zpaste-settings"

    private static let legacyCycleLayoutShortcut = "Alt+L"
    private static let defaultCycleLayoutShortcut = "CommandOrControl+J"

    @Published public var theme: ThemeMode {
        didSet { refreshResolvedTheme(); persist() }
    }
    @Published public var accentColor: String {
        didSet { persist() }
    }
    @Published public var language: LanguageMode {
        didSet { persist() }
    }
    @Published public var launchAtLogin: Bool {
        didSet { persist() }
    }
    @Published public var historyRetention: Int {
        didSet { persist() }
    }
    @Published public var maxItems: Int {
        didSet { persist() }
    }
    @Published public var iCloudSync: Bool {
        didSet { persist() }
    }
    @Published public var hasCompletedOnboarding: Bool {
        didSet { persist() }
    }
    @Published public var customShortcut: String {
        didSet { persist() }
    }
    @Published public var sequencePasteShortcut: String {
        didSet { persist() }
    }
    @Published public var batchPasteShortcut: String {
        didSet { persist() }
    }
    @Published public var addToQueueShortcut: String {
        didSet { persist() }
    }
    @Published public var batchPasteSeparator: String {
        didSet { persist() }
    }
    @Published public var toggleFilterShortcut: String {
        didSet { persist() }
    }
    @Published public var togglePreviewShortcut: String {
        didSet { persist() }
    }
    @Published public var openTagShortcut: String {
        didSet { persist() }
    }
    @Published public var openSettingsShortcut: String {
        didSet { persist() }
    }
    @Published public var cycleLayoutShortcut: String {
        didSet { persist() }
    }
    @Published public var widgetFollowFilter: Bool {
        didSet { persist() }
    }
    @Published public var widgetToggleShortcut: String {
        didSet { persist() }
    }
    @Published public var widgetQuickPastePrefix: String {
        didSet { persist() }
    }
    @Published public var layoutMode: LayoutMode {
        didSet { persist() }
    }

    /// The concrete theme currently in effect.
    @Published public private(set) var resolvedTheme: ResolvedTheme

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = AppPaths.settingsDefaults, importLegacy: Bool = true) {
        self.defaults = defaults

        var stored = Self.load(from: defaults)
        if AppPaths.isIsolated {
            stored = (try? Data(contentsOf: AppPaths.supportDirectory.appendingPathComponent("settings.json")))
                .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        }
        if importLegacy, !AppPaths.isIsolated, stored.isEmpty, let imported = Self.importElectronSettings() {
            stored = imported
            if let data = try? JSONSerialization.data(withJSONObject: imported) {
                defaults.set(data, forKey: Self.storageKey)
            }
        }
        var values = Self.defaults
        for (key, value) in stored {
            values[key] = value
        }
        values = Self.normalize(values)

        theme = values["theme"] as? ThemeMode ?? .auto
        accentColor = values["accentColor"] as? String ?? "#FF7F43"
        language = values["language"] as? LanguageMode ?? .auto
        launchAtLogin = values["launchAtLogin"] as? Bool ?? false
        historyRetention = values["historyRetention"] as? Int ?? 30
        maxItems = values["maxItems"] as? Int ?? MaxItems.default
        iCloudSync = values["iCloudSync"] as? Bool ?? false
        hasCompletedOnboarding = values["hasCompletedOnboarding"] as? Bool ?? false
        customShortcut = values["customShortcut"] as? String ?? "Shift+CommandOrControl+V"
        sequencePasteShortcut = values["sequencePasteShortcut"] as? String ?? "CommandOrControl+;"
        batchPasteShortcut = values["batchPasteShortcut"] as? String ?? "CommandOrControl+'"
        addToQueueShortcut = values["addToQueueShortcut"] as? String ?? "Space"
        batchPasteSeparator = values["batchPasteSeparator"] as? String ?? "\n"
        toggleFilterShortcut = values["toggleFilterShortcut"] as? String ?? "CommandOrControl+F"
        togglePreviewShortcut = values["togglePreviewShortcut"] as? String ?? "Alt"
        openTagShortcut = values["openTagShortcut"] as? String ?? "T"
        openSettingsShortcut = values["openSettingsShortcut"] as? String ?? "CommandOrControl+,"
        cycleLayoutShortcut = values["cycleLayoutShortcut"] as? String ?? Self.defaultCycleLayoutShortcut
        widgetFollowFilter = values["widgetFollowFilter"] as? Bool ?? false
        widgetToggleShortcut = values["widgetToggleShortcut"] as? String ?? "Alt+W"
        widgetQuickPastePrefix = values["widgetQuickPastePrefix"] as? String ?? "Alt"
        layoutMode = values["layoutMode"] as? LayoutMode ?? .center

        let resolvedThemeValue = (values["theme"] as? ThemeMode ?? .auto)
            .resolved(systemTheme: Self.systemTheme())
        resolvedTheme = resolvedThemeValue
    }

    // MARK: - Defaults

    private static var defaults: [String: Any] {
        [
            "theme": ThemeMode.auto.rawValue,
            "accentColor": "#FF7F43",
            "language": LanguageMode.auto.rawValue,
            "launchAtLogin": false,
            "historyRetention": 30,
            "maxItems": MaxItems.default,
            "iCloudSync": false,
            "hasCompletedOnboarding": false,
            "customShortcut": "Shift+CommandOrControl+V",
            "sequencePasteShortcut": "CommandOrControl+;",
            "batchPasteShortcut": "CommandOrControl+'",
            "addToQueueShortcut": "Space",
            "batchPasteSeparator": "\n",
            "toggleFilterShortcut": "CommandOrControl+F",
            "togglePreviewShortcut": "Alt",
            "openTagShortcut": "T",
            "openSettingsShortcut": "CommandOrControl+,",
            "cycleLayoutShortcut": defaultCycleLayoutShortcut,
            "widgetFollowFilter": false,
            "widgetToggleShortcut": "Alt+W",
            "widgetQuickPastePrefix": "Alt",
            "layoutMode": LayoutMode.center.rawValue
        ]
    }

    // MARK: - Persistence

    /// The settings of the previous Electron build, if they exist.
    private static func importElectronSettings() -> [String: Any]? {
        ElectronSettingsImporter.loadSettings()
    }

    private static func load(from defaults: UserDefaults) -> [String: Any] {
        guard let data = defaults.data(forKey: storageKey),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any]
        else { return [:] }
        return dict
    }

    private static func normalize(_ values: [String: Any]) -> [String: Any] {
        var values = values

        if let maxItems = values["maxItems"] as? Int {
            values["maxItems"] = MaxItems.normalize(maxItems)
        }
        if values["cycleLayoutShortcut"] as? String == legacyCycleLayoutShortcut {
            values["cycleLayoutShortcut"] = defaultCycleLayoutShortcut
        }
        // Coerce the string backed values into their enum representations.
        if let raw = values["theme"] as? String {
            values["theme"] = ThemeMode(rawValue: raw) ?? .auto
        }
        if let raw = values["language"] as? String {
            values["language"] = LanguageMode(rawValue: raw) ?? .auto
        }
        if let raw = values["layoutMode"] as? String {
            values["layoutMode"] = LayoutMode(rawValue: raw) ?? .center
        }
        return values
    }

    private func persist() {
        let payload: [String: Any] = [
            "theme": theme.rawValue,
            "accentColor": accentColor,
            "language": language.rawValue,
            "launchAtLogin": launchAtLogin,
            "historyRetention": historyRetention,
            "maxItems": MaxItems.normalize(maxItems),
            "iCloudSync": iCloudSync,
            "hasCompletedOnboarding": hasCompletedOnboarding,
            "customShortcut": customShortcut,
            "sequencePasteShortcut": sequencePasteShortcut,
            "batchPasteShortcut": batchPasteShortcut,
            "addToQueueShortcut": addToQueueShortcut,
            "batchPasteSeparator": batchPasteSeparator,
            "toggleFilterShortcut": toggleFilterShortcut,
            "togglePreviewShortcut": togglePreviewShortcut,
            "openTagShortcut": openTagShortcut,
            "openSettingsShortcut": openSettingsShortcut,
            "cycleLayoutShortcut": cycleLayoutShortcut,
            "widgetFollowFilter": widgetFollowFilter,
            "widgetToggleShortcut": widgetToggleShortcut,
            "widgetQuickPastePrefix": widgetQuickPastePrefix,
            "layoutMode": layoutMode.rawValue
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        if AppPaths.isIsolated {
            try? data.write(to: AppPaths.supportDirectory.appendingPathComponent("settings.json"), options: .atomic)
        } else {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Theme

    /// The appearance the system currently reports.
    public static func systemTheme() -> ResolvedTheme {
        let appearance = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        return appearance == "Dark" ? .dark : .light
    }

    /// Recomputes the effective theme, e.g. after the system appearance changed.
    public func refreshResolvedTheme() {
        let resolved = theme.resolved(systemTheme: Self.systemTheme())
        if resolved != resolvedTheme {
            resolvedTheme = resolved
        }
    }

    /// The language the UI should use right now.
    public func resolvedLanguage(systemLanguage: String? = Locale.preferredLanguages.first) -> AppLanguage {
        language.resolved(systemLanguage: systemLanguage)
    }

    /// The separators offered in the settings window.
    public static let batchSeparatorOptions: [(key: String, value: String)] = [
        ("settings.shortcuts.separator.newline", "\n"),
        ("settings.shortcuts.separator.tab", "\t"),
        ("settings.shortcuts.separator.comma", ", "),
        ("settings.shortcuts.separator.space", " ")
    ]
}
