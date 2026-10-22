import AppKit
import StashCore
import SwiftUI

/// The keyboard shortcut settings.
struct ShortcutsSectionView: View {
    @ObservedObject var settings: SettingsStore
    let theme: StashTheme
    var onShortcutsChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionTitle(title: L10n.t("settings.shortcuts.title"), theme: theme)

            SettingsGroupCard(theme: theme) {
                SettingsRow(
                    title: L10n.t("settings.shortcuts.showPanel"),
                    description: L10n.t("settings.shortcuts.showPanel.desc"),
                    theme: theme
                ) {
                    ShortcutRecorder(shortcut: $settings.customShortcut, theme: theme, isGlobal: true)
                        .onChange(of: settings.customShortcut) { _ in onShortcutsChanged() }
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.shortcuts.sequencePaste"),
                    description: L10n.t("settings.shortcuts.sequencePaste.desc"),
                    theme: theme
                ) {
                    ShortcutRecorder(shortcut: $settings.sequencePasteShortcut, theme: theme, isGlobal: true)
                        .onChange(of: settings.sequencePasteShortcut) { _ in onShortcutsChanged() }
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.shortcuts.batchPaste"),
                    description: L10n.t("settings.shortcuts.batchPaste.desc"),
                    theme: theme
                ) {
                    ShortcutRecorder(shortcut: $settings.batchPasteShortcut, theme: theme, isGlobal: true)
                        .onChange(of: settings.batchPasteShortcut) { _ in onShortcutsChanged() }
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.shortcuts.addToQueue"),
                    description: L10n.t("settings.shortcuts.addToQueue.desc"),
                    theme: theme
                ) {
                    ShortcutRecorder(shortcut: $settings.addToQueueShortcut, theme: theme)
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.shortcuts.toggleFilter"),
                    description: L10n.t("settings.shortcuts.toggleFilter.desc"),
                    theme: theme
                ) {
                    ShortcutRecorder(shortcut: $settings.toggleFilterShortcut, theme: theme)
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.shortcuts.togglePreview"),
                    description: L10n.t("settings.shortcuts.togglePreview.desc"),
                    theme: theme
                ) {
                    ShortcutRecorder(shortcut: $settings.togglePreviewShortcut, theme: theme)
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.shortcuts.openTag"),
                    description: L10n.t("settings.shortcuts.openTag.desc"),
                    theme: theme
                ) {
                    ShortcutRecorder(shortcut: $settings.openTagShortcut, theme: theme)
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.shortcuts.openSettings"),
                    description: L10n.t("settings.shortcuts.openSettings.desc"),
                    theme: theme
                ) {
                    ShortcutRecorder(shortcut: $settings.openSettingsShortcut, theme: theme)
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.shortcuts.cycleLayout"),
                    description: L10n.t("settings.shortcuts.cycleLayout.desc"),
                    theme: theme
                ) {
                    ShortcutRecorder(shortcut: $settings.cycleLayoutShortcut, theme: theme, isGlobal: true)
                        .onChange(of: settings.cycleLayoutShortcut) { _ in
                            onShortcutsChanged()
                        }
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.shortcuts.batchSeparator"),
                    description: L10n.t("settings.shortcuts.batchSeparator.desc"),
                    theme: theme
                ) {
                    AppPicker(
                        selection: Binding(
                            get: { settings.batchPasteSeparator },
                            set: { newValue in
                                settings.batchPasteSeparator = newValue
                                NotificationCenter.default.post(
                                    name: .stashBatchSeparatorChanged,
                                    object: newValue
                                )
                            }
                        ),
                        options: SettingsStore.batchSeparatorOptions.map { ($0.value, L10n.t($0.key)) },
                        theme: theme,
                        width: 110
                    )
                }
            }

            Text(L10n.t("settings.shortcuts.hint"))
                .font(.system(size: 10))
                .foregroundColor(theme.mutedForeground)
                .padding(.top, 4)
                .padding(.horizontal, 4)
        }
    }
}

/// The widget settings.
struct WidgetSectionView: View {
    @ObservedObject var settings: SettingsStore
    let theme: StashTheme
    var onWidgetChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionTitle(title: L10n.t("settings.nav.widget"), theme: theme)

            SettingsGroupCard(theme: theme) {
                SettingsRow(
                    title: L10n.t("settings.general.widgetFollowFilter"),
                    description: L10n.t("settings.general.widgetFollowFilter.desc"),
                    theme: theme
                ) {
                    AppPicker(
                        selection: Binding(
                            get: { settings.widgetFollowFilter },
                            set: { newValue in
                                settings.widgetFollowFilter = newValue
                                NotificationCenter.default.post(
                                    name: .stashWidgetFollowFilterChanged,
                                    object: newValue
                                )
                            }
                        ),
                        options: [
                            (false, L10n.t("settings.general.widgetFollowFilter.independent")),
                            (true, L10n.t("settings.general.widgetFollowFilter.follow"))
                        ],
                        theme: theme,
                        width: 180
                    )
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.shortcuts.widgetToggle"),
                    description: L10n.t("settings.shortcuts.widgetToggle.desc"),
                    theme: theme
                ) {
                    ShortcutRecorder(shortcut: $settings.widgetToggleShortcut, theme: theme, isGlobal: true)
                        .onChange(of: settings.widgetToggleShortcut) { _ in
                            onWidgetChanged()
                        }
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.shortcuts.widgetQuickPastePrefix"),
                    description: L10n.t("settings.shortcuts.widgetQuickPastePrefix.desc"),
                    theme: theme
                ) {
                    AppPicker(
                        selection: Binding(
                            get: { settings.widgetQuickPastePrefix },
                            set: { newValue in
                                settings.widgetQuickPastePrefix = newValue
                                onWidgetChanged()
                            }
                        ),
                        options: [
                            ("Alt", L10n.t("settings.shortcuts.widgetQuickPastePrefix.alt")),
                            ("Control", L10n.t("settings.shortcuts.widgetQuickPastePrefix.control")),
                            ("CommandOrControl", L10n.t("settings.shortcuts.widgetQuickPastePrefix.command"))
                        ],
                        theme: theme,
                        width: 160
                    )
                }
            }
        }
    }
}

/// The iCloud synchronisation settings.
struct SyncSectionView: View {
    @ObservedObject var settings: SettingsStore
    let theme: StashTheme
    var onSyncChanged: (Bool) -> Void

    @State private var isSyncing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionTitle(title: L10n.t("settings.sync.title"), theme: theme)

            SettingsGroupCard(theme: theme) {
                SettingsRow(
                    title: L10n.t("settings.sync.enable"),
                    description: L10n.t("settings.sync.enable.desc"),
                    theme: theme
                ) {
                    AppToggle(
                        isOn: Binding(
                            get: { settings.iCloudSync },
                            set: { newValue in
                                settings.iCloudSync = newValue
                                onSyncChanged(newValue)
                            }
                        ),
                        theme: theme
                    )
                }
                Divider().overlay(theme.border.opacity(0.5))

                SettingsRow(
                    title: L10n.t("settings.sync.now"),
                    description: L10n.t("settings.sync.now.desc"),
                    theme: theme
                ) {
                    AppButton(
                        title: isSyncing ? L10n.t("settings.sync.syncing") : L10n.t("settings.sync.syncButton"),
                        theme: theme,
                        isEnabled: settings.iCloudSync && !isSyncing
                    ) {
                        isSyncing = true
                        NotificationCenter.default.post(name: .stashSyncNow, object: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isSyncing = false
                        }
                    }
                }
            }
        }
    }
}

/// The privacy settings.
struct PrivacySectionView: View {
    let theme: StashTheme
    var onClearAll: () -> Void
    @State private var isConfirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionTitle(title: L10n.t("settings.privacy.title"), theme: theme)
            AccessibilityPermissionRow(theme: theme)
                .padding(.bottom, 16)

            SettingsGroupCard(theme: theme) {
                SettingsRow(
                    title: L10n.t("settings.privacy.clearAll"),
                    description: L10n.t("settings.privacy.clearAll.desc"),
                    theme: theme
                ) {
                    if isConfirming {
                        AppButton(
                            title: L10n.t("settings.privacy.confirmClear"),
                            theme: theme,
                            isDestructive: true,
                            isProminent: true
                        ) {
                            isConfirming = false
                            onClearAll()
                        }
                    } else {
                        AppButton(
                            title: L10n.t("settings.privacy.clearButton"),
                            theme: theme,
                            isDestructive: true
                        ) {
                            isConfirming = true
                        }
                    }
                }
            }
        }
    }
}

/// The appearance settings.
struct ThemeSectionView: View {
    @ObservedObject var settings: SettingsStore
    let theme: StashTheme
    @State private var hexDraft = ""

    private let presets = ["#FF7F43", "#8D6DE0", "#1A7DE8", "#22A05A", "#E83060", "#F5A623"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionTitle(title: L10n.t("settings.theme.title"), theme: theme)

            HStack(spacing: 10) {
                themeCard(.auto, "monitor", "settings.theme.auto")
                themeCard(.dark, "moon", "settings.theme.dark")
                themeCard(.light, "sun", "settings.theme.light")
            }
            .padding(.bottom, 16)

            SettingsGroupCard(theme: theme) {
                SettingsRow(
                    title: L10n.t("settings.theme.accentColor"),
                    description: nil,
                    theme: theme
                ) {
                    HStack(spacing: 10) {
                        ForEach(presets, id: \.self) { preset in
                            Button {
                                settings.accentColor = preset
                                hexDraft = preset
                            } label: {
                                Circle()
                                    .fill(Color(hex: preset))
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Circle()
                                            .stroke(theme.foreground.opacity(0.25), lineWidth: 1)
                                    )
                                    .scaleEffect(settings.accentColor == preset ? 1.12 : 1)
                                    .overlay(
                                        Circle()
                                            .stroke(theme.accentColor, lineWidth: 2)
                                            .scaleEffect(settings.accentColor == preset ? 1.12 : 0.6)
                                            .opacity(settings.accentColor == preset ? 1 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help(preset)
                        }

                        ColorPicker("", selection: Binding(
                            get: { Color(hex: settings.accentColor) },
                            set: { newValue in
                                let hex = newValue.hexString
                                settings.accentColor = hex
                                hexDraft = hex
                            }
                        ), supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 26, height: 26)
                        .help(L10n.t("settings.theme.accentCustom"))

                        TextField("#FF7F43", text: $hexDraft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(theme.foreground)
                            .frame(width: 88)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(theme.muted)
                            )
                            .onAppear { hexDraft = settings.accentColor }
                            .onChange(of: settings.accentColor) { newValue in
                                if hexDraft != newValue { hexDraft = newValue }
                            }
                            .onChange(of: hexDraft) { newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                                guard trimmed.count <= 7,
                                      trimmed.dropFirst().allSatisfy({ $0.isHexDigit })
                                else { return }
                                if trimmed.count == 7, trimmed.hasPrefix("#") {
                                    settings.accentColor = trimmed
                                }
                            }
                            .onSubmit { commitHex() }
                            .onExitCommand { hexDraft = settings.accentColor }
                    }
                }
            }
        }
    }

    private func themeCard(_ mode: ThemeMode, _ icon: String, _ labelKey: String) -> some View {
        let isActive = settings.theme == mode
        return Button {
            settings.theme = mode
            settings.refreshResolvedTheme()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                Text(L10n.t(labelKey))
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isActive ? theme.accentColor : theme.foreground.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? theme.accentColor.opacity(0.12) : theme.cardElevated.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isActive ? theme.accentColor : theme.border.opacity(0.6), lineWidth: isActive ? 1.5 : 0.8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(theme.subtleSpecularHighlight, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func commitHex() {
        let trimmed = hexDraft.trimmingCharacters(in: .whitespaces)
        if trimmed.count == 7, trimmed.hasPrefix("#"), trimmed.dropFirst().allSatisfy({ $0.isHexDigit }) {
            settings.accentColor = trimmed
        } else {
            hexDraft = settings.accentColor
        }
    }
}

/// The tag management settings.
struct TagsSectionView: View {
    let repository: Repository
    let theme: StashTheme

    @State private var tags: [TagWithCount] = []
    @State private var stats: TagStats = TagStats(total: 0, singleUse: 0)
    @State private var renamingSlug: String?
    @State private var renameValue = ""
    @State private var mergingSlug: String?
    @State private var mergeTarget = ""
    @State private var armedDeleteSlug: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionTitle(title: L10n.t("settings.tags.title"), theme: theme)

            HStack(spacing: 10) {
                statCard(L10n.t("settings.tags.total"), stats.total)
                statCard(L10n.t("settings.tags.singleUse"), stats.singleUse)
            }
            .padding(.bottom, 12)

            if stats.total > 15 {
                HStack(spacing: 8) {
                    Image(systemName: Symbols.warning)
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    Text(L10n.t("settings.tags.tooMany"))
                        .font(.system(size: 11))
                        .foregroundColor(theme.foreground)
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.yellow.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
                )
                .padding(.bottom, 12)
            }

            if tags.isEmpty {
                Text(L10n.t("settings.tags.empty"))
                    .font(.system(size: 11))
                    .foregroundColor(theme.mutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else {
                SettingsGroupCard(theme: theme) {
                    ForEach(Array(tags.enumerated()), id: \.element.id) { index, tag in
                        tagRow(tag)
                        if index < tags.count - 1 {
                            Divider().overlay(theme.border.opacity(0.5))
                        }
                    }
                }
            }
        }
        .onAppear { load() }
    }

    private func statCard(_ caption: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.foreground)
            Text(caption)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.cardElevated.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.border.opacity(0.6), lineWidth: 0.8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.subtleSpecularHighlight, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func tagRow(_ tag: TagWithCount) -> some View {
        HStack(spacing: 8) {
            Image(systemName: Symbols.tag)
                .font(.system(size: 11))
                .foregroundColor(theme.mutedForeground)

            if renamingSlug == tag.slug {
                TextField(L10n.t("settings.tags.rename"), text: $renameValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(theme.foreground)
                    .onSubmit { commitRename(tag) }
                    .onExitCommand { renamingSlug = nil }
            } else if mergingSlug == tag.slug {
                Picker("", selection: $mergeTarget) {
                    Text(L10n.t("settings.tags.selectTarget")).tag("")
                    ForEach(tags.filter { $0.slug != tag.slug }) { other in
                        Text(other.name).tag(other.slug)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 180)
            } else {
                Text(tag.name)
                    .font(.system(size: 12))
                    .foregroundColor(theme.foreground)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("\(tag.count)")
                .font(.system(size: 10))
                .foregroundColor(theme.mutedForeground)

            if renamingSlug == tag.slug {
                AppButton(title: L10n.t("common.confirm"), theme: theme, isProminent: true) {
                    commitRename(tag)
                }
                AppButton(title: L10n.t("common.cancel"), theme: theme) {
                    renamingSlug = nil
                }
            } else if mergingSlug == tag.slug {
                AppButton(
                    title: L10n.t("settings.tags.merge"),
                    theme: theme,
                    isProminent: true,
                    isEnabled: !mergeTarget.isEmpty
                ) {
                    commitMerge(tag)
                }
                AppButton(title: L10n.t("common.cancel"), theme: theme) {
                    mergingSlug = nil
                    mergeTarget = ""
                }
            } else {
                Button {
                    renamingSlug = tag.slug
                    renameValue = tag.name
                } label: {
                    Image(systemName: Symbols.pencil).font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(theme.mutedForeground)
                .help(L10n.t("settings.tags.rename"))

                Button {
                    mergingSlug = tag.slug
                    mergeTarget = ""
                } label: {
                    Image(systemName: "arrow.triangle.merge").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(theme.mutedForeground)
                .help(L10n.t("settings.tags.mergeTo"))

                Button {
                    if armedDeleteSlug == tag.slug {
                        try? repository.deleteTag(slug: tag.slug)
                        armedDeleteSlug = nil
                        load()
                    } else {
                        armedDeleteSlug = tag.slug
                    }
                } label: {
                    Image(systemName: Symbols.trash).font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(armedDeleteSlug == tag.slug ? theme.destructive : theme.mutedForeground)
                .help(armedDeleteSlug == tag.slug
                      ? L10n.t("settings.tags.confirmDelete")
                      : L10n.t("common.delete"))
            }
        }
        .padding(.vertical, 7)
    }

    private func load() {
        tags = (try? repository.listTagsWithCounts()) ?? []
        stats = (try? repository.getTagStats()) ?? TagStats(total: 0, singleUse: 0)
    }

    private func commitRename(_ tag: TagWithCount) {
        let trimmed = renameValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        try? repository.renameTag(slug: tag.slug, nextName: trimmed)
        renamingSlug = nil
        load()
    }

    private func commitMerge(_ tag: TagWithCount) {
        let target = mergeTarget.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }
        try? repository.mergeTag(sourceSlug: tag.slug, targetSlug: target)
        mergingSlug = nil
        mergeTarget = ""
        load()
    }
}

/// The about section including the update flow.
struct AboutSectionView: View {
    let version: String
    let theme: StashTheme
    @ObservedObject var updater: UpdateController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionTitle(title: L10n.t("settings.about.title"), theme: theme)

            SettingsGroupCard(theme: theme) {
                HStack(spacing: 16) {
                    AppLogoView(size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stash")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.foreground)
                        Text(L10n.t("settings.about.version", ["version": version]))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.mutedForeground)
                        Text(L10n.t("settings.about.description"))
                            .font(.system(size: 11))
                            .foregroundColor(theme.mutedForeground)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().overlay(theme.border.opacity(0.5))

                HStack(spacing: 12) {
                    updateButton

                    if updater.phase == .downloading {
                        VStack(alignment: .leading, spacing: 4) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(theme.muted)
                                    Capsule()
                                        .fill(theme.accentColor)
                                        .frame(width: geometry.size.width * updater.percent / 100)
                                }
                            }
                            .frame(height: 4)

                            HStack {
                                Text(L10n.t("settings.about.downloadProgress", ["percent": String(Int(updater.percent))]))
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.mutedForeground)
                                Spacer()
                                if updater.bytesPerSecond > 0 {
                                    Text(L10n.t("settings.about.downloadSpeed", ["speed": Self.formatBytes(updater.bytesPerSecond)]))
                                        .font(.system(size: 10))
                                        .foregroundColor(theme.mutedForeground)
                                }
                            }
                        }
                        .frame(maxWidth: 220)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            statusLine
                .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var updateButton: some View {
        switch updater.phase {
        case .checking:
            AppButton(title: L10n.t("settings.about.checking"), theme: theme, isEnabled: false) {}
        case .upToDate:
            AppButton(title: L10n.t("settings.about.checkUpdate"), theme: theme) {
                updater.check()
            }
        case .available:
            AppButton(title: L10n.t("settings.about.downloadUpdate"), theme: theme, isProminent: true) {
                updater.download()
            }
        case .downloading:
            EmptyView()
        case .downloaded:
            AppButton(title: L10n.t("settings.about.restartInstall"), theme: theme, isProminent: true) {
                updater.install()
            }
        case .error:
            AppButton(title: L10n.t("settings.about.checkUpdate"), theme: theme) {
                updater.check()
            }
        case .downloadError:
            AppButton(title: L10n.t("settings.about.downloadUpdate"), theme: theme) {
                updater.download()
            }
        case .idle:
            AppButton(title: L10n.t("settings.about.checkUpdate"), theme: theme) {
                updater.check()
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch updater.phase {
        case .upToDate:
            statusLabel(L10n.t("settings.about.upToDate"), color: .green, icon: Symbols.checkCircle)
        case .available, .downloading:
            statusLabel(L10n.t("settings.about.updateAvailable", ["version": updater.newVersion]),
                        color: theme.accentColor, icon: Symbols.info)
        case .downloaded:
            statusLabel(L10n.t("settings.about.downloadReady"), color: .green, icon: Symbols.checkCircle)
        case .error:
            statusLabel(L10n.t("settings.about.checkFailed"), color: theme.destructive, icon: Symbols.warning)
        case .downloadError:
            VStack(alignment: .leading, spacing: 4) {
                statusLabel(L10n.t("settings.about.downloadFailed"), color: theme.destructive, icon: Symbols.warning)
                if !updater.errorMessage.isEmpty {
                    Text(updater.errorMessage)
                        .font(.system(size: 10))
                        .foregroundColor(theme.mutedForeground)
                }
            }
        default:
            EmptyView()
        }
    }

    private func statusLabel(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(.system(size: 11))
        }
        .foregroundColor(color)
    }

    static func formatBytes(_ bytes: Double) -> String {
        if bytes < 1024 { return String(format: "%.0f B", bytes) }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", bytes / 1024) }
        return String(format: "%.1f MB", bytes / (1024 * 1024))
    }
}

public extension Notification.Name {
    static let stashSyncNow = Notification.Name("com.zpaste.app.syncNow")
    static let stashBatchSeparatorChanged = Notification.Name("com.zpaste.app.batchSeparatorChanged")
    static let stashWidgetFollowFilterChanged = Notification.Name("com.zpaste.app.widgetFollowFilterChanged")
}
