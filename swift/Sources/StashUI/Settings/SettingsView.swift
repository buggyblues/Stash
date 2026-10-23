import StashCore
import SwiftUI

/// The sections of the settings window.
public enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case widget
    case sync
    case privacy
    case theme
    case tags
    case about

    public var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .general: return "settings.nav.general"
        case .shortcuts: return "settings.nav.shortcuts"
        case .widget: return "settings.nav.widget"
        case .sync: return "settings.nav.sync"
        case .privacy: return "settings.nav.privacy"
        case .theme: return "settings.nav.theme"
        case .tags: return "settings.nav.tags"
        case .about: return "settings.nav.about"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "keyboard"
        case .widget: return "square.grid.2x2"
        case .sync: return "cloud"
        case .privacy: return "lock"
        case .theme: return "paintpalette"
        case .tags: return "tag"
        case .about: return "info.circle"
        }
    }
}

/// The settings window content.
public struct SettingsView: View {
    @ObservedObject public var settings: SettingsStore
    @ObservedObject public var toast: ToastCenter
    /// The theme follows the settings, so no view tree has to be rebuilt.
    private var theme: StashTheme {
        StashTheme(resolved: settings.resolvedTheme, accentHex: settings.accentColor)
    }
    public let repository: Repository
    public let version: String
    public let updater: UpdateController
    public var onClose: () -> Void
    public var onLaunchAtLoginChanged: (Bool) -> Void
    public var onSyncChanged: (Bool) -> Void
    public var onShortcutsChanged: () -> Void
    public var onLayoutModeChanged: (LayoutMode) -> Void
    public var onWidgetChanged: () -> Void
    public var onClearAll: () -> Void

    @ObservedObject private var localization = Localization.shared
    @State private var section: SettingsSection = .general

    public init(
        settings: SettingsStore,
        repository: Repository,
        version: String,
        updater: UpdateController = UpdateController(currentVersion: "1.0.0"),
        toast: ToastCenter = ToastCenter(),
        onClose: @escaping () -> Void = {},
        onLaunchAtLoginChanged: @escaping (Bool) -> Void = { _ in },
        onSyncChanged: @escaping (Bool) -> Void = { _ in },
        onShortcutsChanged: @escaping () -> Void = {},
        onLayoutModeChanged: @escaping (LayoutMode) -> Void = { _ in },
        onWidgetChanged: @escaping () -> Void = {},
        onClearAll: @escaping () -> Void = {}
    ) {
        self.settings = settings
        self.repository = repository
        self.version = version
        self.updater = updater
        self.toast = toast
        self.onClose = onClose
        self.onLaunchAtLoginChanged = onLaunchAtLoginChanged
        self.onSyncChanged = onSyncChanged
        self.onShortcutsChanged = onShortcutsChanged
        self.onLayoutModeChanged = onLayoutModeChanged
        self.onWidgetChanged = onWidgetChanged
        self.onClearAll = onClearAll
    }

    public var body: some View {
        navigation
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onClose) {
                        Label(L10n.t("common.close"), systemImage: "xmark")
                    }
                    .labelStyle(.iconOnly)
                    .help(L10n.t("common.close") + " (⌘W)")
                    .accessibilityLabel(L10n.t("common.close"))
                    .keyboardShortcut("w", modifiers: .command)
                }
            }
            .environment(\.colorScheme, theme.isDark ? .dark : .light)
            .tint(theme.accentColor)
            .overlay(alignment: .bottom) { toastOverlay }
            .environmentObject(settings)
    }

    @ViewBuilder private var navigation: some View {
        if #available(macOS 13.0, *) {
            NavigationSplitView {
                sidebar
                    .navigationTitle(L10n.t("settings.title"))
                    .navigationSplitViewColumnWidth(min: 180, ideal: 190, max: 230)
            } detail: {
                content
                    .navigationTitle(L10n.t(section.titleKey))
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 190)
                    .background(VisualEffectBlur(material: .sidebar))
                Divider()
                content
            }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let message = toast.message {
            Text(message.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.cardElevated)
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
                .padding(.bottom, 16)
        }
    }

    private var sidebar: some View {
        List(selection: Binding<SettingsSection?>(
            get: { section },
            set: { if let value = $0 { section = value } }
        )) {
            ForEach(SettingsSection.allCases) { item in
                Label(L10n.t(item.titleKey), systemImage: item.icon)
                    .font(.system(size: 13))
                    .padding(.vertical, 4)
                    .tag(item)
            }
        }
        .listStyle(.sidebar)
        .accessibilityLabel(L10n.t("settings.title"))
    }

    private var content: some View {
        ZoomContainer(identifier: WindowIdentifiers.settings) {
            settingsForm
        }
    }

    private var settingsForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch section {
                case .general:
                    GeneralSectionView(
                        settings: settings,
                        theme: theme,
                        toast: toast,
                        onLaunchAtLoginChanged: onLaunchAtLoginChanged,
                        onLayoutModeChanged: onLayoutModeChanged
                    )
                case .shortcuts:
                    ShortcutsSectionView(
                        settings: settings,
                        theme: theme,
                        onShortcutsChanged: onShortcutsChanged
                    )
                case .widget:
                    WidgetSectionView(
                        settings: settings,
                        theme: theme,
                        onWidgetChanged: onWidgetChanged
                    )
                case .sync:
                    SyncSectionView(
                        settings: settings,
                        theme: theme,
                        onSyncChanged: onSyncChanged
                    )
                case .privacy:
                    PrivacySectionView(theme: theme, onClearAll: onClearAll)
                case .theme:
                    ThemeSectionView(settings: settings, theme: theme)
                case .tags:
                    TagsSectionView(repository: repository, theme: theme)
                case .about:
                    AboutSectionView(version: version, theme: theme, updater: updater)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .background(theme.background)
    }
}

/// The general settings.
struct GeneralSectionView: View {
    @ObservedObject var settings: SettingsStore
    let theme: StashTheme
    @ObservedObject var toast: ToastCenter
    var onLaunchAtLoginChanged: (Bool) -> Void
    var onLayoutModeChanged: (LayoutMode) -> Void

    @State private var customMaxItems = ""
    @State private var isEditingCustom = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionTitle(title: L10n.t("settings.general.title"), theme: theme)

            SettingsGroupCard(theme: theme) {
                SettingsRow(
                    title: L10n.t("settings.general.language"),
                    description: L10n.t("settings.general.language.desc"),
                    theme: theme
                ) {
                    AppPicker(
                        selection: Binding(
                            get: { settings.language },
                            set: { newValue in
                                settings.language = newValue
                                Localization.shared.setLanguage(settings.resolvedLanguage())
                            }
                        ),
                        options: [
                            (LanguageMode.auto, L10n.t("settings.general.language.auto")),
                            (LanguageMode.simplifiedChinese, L10n.t("settings.general.language.zhCN")),
                            (LanguageMode.english, L10n.t("settings.general.language.en")),
                            (LanguageMode.traditionalChinese, L10n.t("settings.general.language.zhTW"))
                        ],
                        theme: theme
                    )
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.general.layoutMode"),
                    description: L10n.t("settings.general.layoutMode.desc"),
                    theme: theme
                ) {
                    AppPicker(
                        selection: Binding(
                            get: { settings.layoutMode },
                            set: { newValue in
                                settings.layoutMode = newValue
                                onLayoutModeChanged(newValue)
                            }
                        ),
                        options: LayoutMode.allCases.map { ($0, L10n.t($0.localizationKey)) },
                        theme: theme
                    )
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.general.launchAtLogin"),
                    description: L10n.t("settings.general.launchAtLogin.desc"),
                    theme: theme
                ) {
                    AppToggle(
                        isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { newValue in
                                settings.launchAtLogin = newValue
                                onLaunchAtLoginChanged(newValue)
                            }
                        ),
                        theme: theme
                    )
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.general.historyRetention"),
                    description: L10n.t("settings.general.historyRetention.desc"),
                    theme: theme
                ) {
                    AppPicker(
                        selection: Binding(
                            get: { settings.historyRetention },
                            set: { settings.historyRetention = $0 }
                        ),
                        options: [
                            (1, L10n.t("settings.general.retention.1day")),
                            (7, L10n.t("settings.general.retention.7days")),
                            (30, L10n.t("settings.general.retention.30days")),
                            (0, L10n.t("settings.general.retention.forever"))
                        ],
                        theme: theme,
                        width: 120
                    )
                }
                Divider().overlay(theme.border.opacity(0.5))

                maxItemsRow
            }
        }
    }

    private var maxItemsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsRow(
                title: L10n.t("settings.general.maxItems"),
                description: L10n.t("settings.general.maxItems.desc"),
                theme: theme
            ) {
                HStack(spacing: 8) {
                    AppPicker(
                        selection: Binding(
                            get: { selectionValue },
                            set: { newValue in
                                if newValue == "custom" {
                                    isEditingCustom = true
                                    customMaxItems = String(max(settings.maxItems, 500))
                                } else {
                                    isEditingCustom = false
                                    let value = newValue == "unlimited" ? 0 : (Int(newValue) ?? MaxItems.default)
                                    settings.maxItems = value
                                }
                            }
                        ),
                        options: [
                            ("500", "500"),
                            ("1000", "1000"),
                            ("2000", "2000"),
                            ("custom", L10n.t("settings.general.maxItems.custom")),
                            ("unlimited", L10n.t("settings.general.maxItems.unlimited"))
                        ],
                        theme: theme,
                        width: 140
                    )

                    if isEditingCustom {
                        TextField(L10n.t("settings.general.maxItems.customPlaceholder"), text: $customMaxItems)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(theme.foreground)
                            .frame(width: 70)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(theme.muted)
                            )
                            .onSubmit { saveCustom() }

                        AppButton(
                            title: L10n.t("common.save"),
                            theme: theme,
                            isEnabled: canSaveCustom
                        ) {
                            saveCustom()
                        }
                    }
                }
            }

            if isEditingCustom {
                Text(L10n.t("settings.general.maxItems.customHint", ["min": String(MaxItems.customMinimum)]))
                    .font(.system(size: 10))
                    .foregroundColor(theme.mutedForeground)
            }
        }
        .padding(.vertical, 4)
    }

    private var selectionValue: String {
        if isEditingCustom { return "custom" }
        if settings.maxItems == 0 { return "unlimited" }
        if MaxItems.isPreset(settings.maxItems) { return String(settings.maxItems) }
        // A custom value keeps the "custom" entry selected.
        return "custom"
    }

    private var canSaveCustom: Bool {
        let trimmed = customMaxItems.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
        return (Int(trimmed) ?? 0) >= MaxItems.customMinimum
    }

    private func saveCustom() {
        guard canSaveCustom else { return }
        settings.maxItems = Int(customMaxItems.trimmingCharacters(in: .whitespaces)) ?? MaxItems.default
        isEditingCustom = false
        toast.show(L10n.t("settings.general.maxItems.saved"))
    }
}
