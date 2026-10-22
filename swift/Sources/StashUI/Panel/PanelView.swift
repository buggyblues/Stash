import AppKit
import StashCore
import SwiftUI

/// The main clipboard panel.
public struct PanelView: View {
    @ObservedObject public var model: PanelViewModel
    @ObservedObject public var settings: SettingsStore
    @ObservedObject public var toast: ToastCenter
    @ObservedObject public var iconStore: AppIconStore

    /// The theme is derived from the settings so that a change is picked up
    /// without recreating the whole view tree.
    private var theme: StashTheme {
        StashTheme(resolved: settings.resolvedTheme, accentHex: settings.accentColor)
    }

    public var onOpenSettings: () -> Void
    public var onOpenOnboarding: () -> Void
    public var onLayoutModeChanged: (LayoutMode) -> Void
    public var onHide: () -> Void

    @ObservedObject private var localization = Localization.shared
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    public init(
        model: PanelViewModel,
        settings: SettingsStore,
        toast: ToastCenter,
        iconStore: AppIconStore,
        onOpenSettings: @escaping () -> Void = {},
        onOpenOnboarding: @escaping () -> Void = {},
        onLayoutModeChanged: @escaping (LayoutMode) -> Void = { _ in },
        onHide: @escaping () -> Void = {}
    ) {
        self.model = model
        self.settings = settings
        self.toast = toast
        self.iconStore = iconStore
        self.onOpenSettings = onOpenSettings
        self.onOpenOnboarding = onOpenOnboarding
        self.onLayoutModeChanged = onLayoutModeChanged
        self.onHide = onHide
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                if usesSidebar {
                    ClipboardSidebarView(model: model, theme: theme, iconStore: iconStore)
                        .frame(width: 174)
                }
                VStack(spacing: 0) {
                    if !usesSidebar { filterRegion }
                    content
                    statusBar
                }
                .background(theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.trailing, 8)
                .padding(.leading, usesSidebar ? 0 : 8)
                .padding(.bottom, 8)
            }
            if model.isQueueActive { queueBanner }
        }
        .stashGlassSurface()
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(StashWindowAppearance().frame(width: 0, height: 0))
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .tint(theme.accentColor)
        .overlay {
            if settings.layoutMode == .bottom, let editingId = model.editingItemId,
               let item = model.items.first(where: { $0.id == editingId }) {
                QuickEditView(item: item, theme: theme,
                              onCancel: { model.editingItemId = nil },
                              onSave: { content in
                                  model.editingItemId = nil
                                  onPasteEditedContent(content, item: item)
                              })
                    .frame(maxWidth: 600)
                    .background(theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.black.opacity(0.2), radius: 12, y: 4)
                    .padding(12)
            }
        }
        .overlay(alignment: .topLeading) { tagPickerBackdrop }
        .overlay(alignment: .topLeading) { tagPickerOverlay }
        .overlay(alignment: .bottom) { toastView }
        .background(
            LocalKeyMonitor { event in
                handleKey(event)
            }
        )
        .onAppear {
            model.loadItems()
            model.loadTags()
            model.updatePreviewSelection()
        }
        .onChange(of: model.selectedIndex) { _ in
            model.updatePreviewSelection()
        }
        .onChange(of: model.isVisible) { visible in
            if visible {
                if model.editingItemId != nil {
                    DispatchQueue.main.async { InputFocus.focusEditor() }
                    return
                }
                searchText = ""
                model.search("")
                model.selectedIndex = 0
                // Items captured while the panel was hidden are reloaded so the
                // active filters apply again.
                model.reloadIfNeeded()
                // The focus is moved outside of the current view update, which
                // SwiftUI does not accept.
                DispatchQueue.main.async { searchFocused = true }
            }
        }
    }

    // MARK: - Header

    private var usesSidebar: Bool {
        settings.layoutMode == .center && !model.filtersCollapsed
    }

    private var header: some View {
        HStack(spacing: 10) {
            if settings.layoutMode != .side {
                AppLogoView(size: 25)
                    .background(DragRegion())
            }
            searchBar
            filterMenu
            iconButton(Symbols.settings, L10n.t("panel.settings.tooltip"), onOpenSettings)
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
    }

    private var filterMenu: some View {
        Menu {
            Toggle(L10n.t(settings.layoutMode == .center ? "panel.navigation.sidebar" : "panel.navigation.filters"), isOn: Binding(
                get: { !model.filtersCollapsed }, set: { model.filtersCollapsed = !$0 }))
            Toggle(L10n.t("panel.navigation.collections"), isOn: Binding(
                get: { !model.tagBarCollapsed }, set: { model.tagBarCollapsed = !$0 }))
            Toggle(L10n.t("panel.navigation.types"), isOn: Binding(
                get: { !model.typeFilterCollapsed }, set: { model.typeFilterCollapsed = !$0 }))
            Toggle(L10n.t("panel.navigation.sources"), isOn: Binding(
                get: { !model.sourceAppFilterCollapsed }, set: { model.sourceAppFilterCollapsed = !$0 }))
            Divider()
            Toggle(L10n.t("panel.filter.byUsage"), isOn: Binding(
                get: { model.sortBy == .usage }, set: { model.setSortBy($0 ? .usage : .recent) }))
            Button(L10n.t("panel.navigation.reset")) {
                model.setLeftFilter(.all)
                model.setFilterType(nil)
                model.setSourceAppFilter(nil)
                model.setSortBy(.recent)
            }
            Divider()
            Menu(L10n.t("panel.navigation.layout")) {
                ForEach(LayoutMode.allCases, id: \.self) { mode in
                    Button {
                        settings.layoutMode = mode
                        onLayoutModeChanged(mode)
                    } label: {
                        if settings.layoutMode == mode {
                            Label(L10n.t(mode.localizationKey), systemImage: "checkmark")
                        } else {
                            Text(L10n.t(mode.localizationKey))
                        }
                    }
                }
            }
            Button(L10n.t("panel.help.tooltip"), action: onOpenOnboarding)
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(L10n.t("panel.navigation.filters"))
        .accessibilityLabel(L10n.t("panel.navigation.filters"))
    }

    private var statusBar: some View {
        HStack {
            Text(L10n.t("panel.status.items", ["count": String(model.items.count)]))
            Spacer()
            Text(L10n.t("panel.status.hint"))
        }
        .font(.system(size: 10))
        .foregroundColor(theme.mutedForeground)
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(theme.background)
    }

    private func iconButton(_ symbol: String, _ tooltip: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.mutedForeground)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(StashToolbarButtonStyle())
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: Symbols.search)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(searchFocused ? theme.accentColor : theme.mutedForeground)
            TextField("", text: $searchText, prompt: Text(L10n.t("panel.search.placeholder")).foregroundColor(theme.mutedForeground))
                .accessibilityLabel(L10n.t("panel.search.placeholder"))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(theme.foreground)
                .autocorrectionDisabled()
                .focused($searchFocused)
                .onSubmit {
                    model.search(searchText)
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    model.search("")
                } label: {
                    Image(systemName: Symbols.clear)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.mutedForeground)
                        .padding(2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.muted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(searchFocused ? theme.accentColor.opacity(0.7) : theme.border, lineWidth: searchFocused ? 1.5 : 0.5)
        )
        .onChange(of: searchText) { newValue in
            scheduleSearch(newValue)
        }
    }

    @State private var searchTask: Task<Void, Never>?

    private func scheduleSearch(_ value: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                model.search(value)
            }
        }
    }

    // MARK: - Filters

    @ViewBuilder
    private var filterRegion: some View {
        if !model.filtersCollapsed {
            CompactFilterBar(model: model, theme: theme)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch settings.layoutMode {
        case .bottom:
            ClipboardCardListView(model: model, theme: theme, iconStore: iconStore)
        case .side:
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    ClipboardListView(model: model, theme: theme, iconStore: iconStore)
                    if !model.previewCollapsed {
                        Divider().overlay(theme.border)
                        previewArea
                            .frame(height: proxy.size.height * 0.4, alignment: .top)
                    } else if showsExpandStrip {
                        expandStrip(horizontal: true)
                            .frame(height: 32)
                    }
                }
            }
        case .center:
            HSplitView {
                ClipboardListView(model: model, theme: theme, iconStore: iconStore)
                    .frame(minWidth: 220, idealWidth: 390, maxWidth: .infinity)
                if !model.previewCollapsed {
                    previewArea
                        .frame(minWidth: 240, idealWidth: 310, maxWidth: .infinity)
                } else if showsExpandStrip {
                    expandStrip(horizontal: false)
                        .frame(width: 32)
                }
            }
        }
    }

    @ViewBuilder
    private var previewArea: some View {
        if let editingId = model.editingItemId,
           let item = model.items.first(where: { $0.id == editingId }) {
            QuickEditView(
                item: item,
                theme: theme,
                onCancel: { model.editingItemId = nil },
                onSave: { newContent in
                    model.editingItemId = nil
                    onPasteEditedContent(newContent, item: item)
                }
            )
        } else if let item = model.previewItem {
            PreviewPanelView(
                item: item,
                model: model,
                theme: theme,
                onToggleCollapse: { model.togglePreview() }
            )
        } else {
            PreviewEmptyView(theme: theme)
        }
    }

    /// The expand strip is only shown when there is something to preview.
    private var showsExpandStrip: Bool {
        model.previewItem != nil || model.selectedItem != nil
    }

    private func expandStrip(horizontal: Bool) -> some View {
        Button {
            model.togglePreview()
        } label: {
            if horizontal {
                Image(systemName: Symbols.expand)
                    .rotationEffect(.degrees(90))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            } else {
                Image(systemName: Symbols.expand)
                    .frame(width: 32)
                    .frame(maxHeight: .infinity)
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(theme.mutedForeground)
        .background(theme.card.opacity(0.6))
        .help(L10n.t("panel.preview.expand"))
    }

    // MARK: - Queue

    private var queueBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.number")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.accentColor)
            Text(L10n.t("panel.queue.active", ["count": String(model.sequenceQueue.count)]))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.accentColor)
            Spacer()
            Button {
                model.clearQueue()
                NotificationCenter.default.post(name: .stashQueueClear, object: nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: Symbols.close).font(.system(size: 9, weight: .bold))
                    Text(L10n.t("panel.queue.abandon"))
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(theme.destructive)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(theme.accentColor.opacity(theme.isDark ? 0.16 : 0.09))
        .overlay(Rectangle().fill(theme.accentColor.opacity(0.25)).frame(height: 1), alignment: .top)
    }

    // MARK: - Tag picker

    /// A click outside of the picker closes it, like the old build.
    @ViewBuilder
    private var tagPickerBackdrop: some View {
        if model.tagPickerItemId != nil {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { model.closeTagPicker() }
        }
    }

    @ViewBuilder
    private var tagPickerOverlay: some View {
        if let itemId = model.tagPickerItemId {
            TagPickerView(itemId: itemId, model: model, theme: theme) {
                model.closeTagPicker()
            }
            .padding(.leading, 12)
            .padding(.top, settings.layoutMode == .bottom ? 12 : 56)
        }
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastView: some View {
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
                .padding(.bottom, 12)
                .transition(.opacity)
        }
    }

    // MARK: - Actions

    private func onPasteEditedContent(_ content: String, item: ClipboardItem) {
        var edited = item
        edited.content = content
        model.onPaste?(edited)
    }

    // MARK: - Keyboard

    private func handleKey(_ event: NSEvent) -> Bool {
        // The panel only handles keys while it is the focused window, so the
        // settings window keeps its own keyboard behaviour.
        guard NSApp.keyWindow?.identifier == WindowIdentifiers.panel else { return false }

        let isInput = InputFocus.isTextInputFocused
        let info = Self.keyInfo(for: event)

        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.hasMarkedText() { return false }
        if model.editingItemId != nil || model.isEditingTitle { return false }


        // The tag picker owns the keyboard while it is open.
        if model.tagPickerItemId != nil {
            switch info.key {
            case "ArrowDown":
                model.moveTagPickerCursor(by: 1)
                return true
            case "ArrowUp":
                model.moveTagPickerCursor(by: -1)
                return true
            case "Enter":
                model.applyTagPickerCursor()
                return true
            case "Escape":
                model.closeTagPicker()
                return true
            default:
                break
            }
        }

        switch info.key {
        case "ArrowRight" where settings.layoutMode == .bottom && !isInput:
            model.moveSelection(by: 1)
            return true
        case "ArrowLeft" where settings.layoutMode == .bottom && !isInput:
            model.moveSelection(by: -1)
            return true
        case "ArrowDown":
            model.moveSelection(by: 1)
            return true
        case "ArrowUp":
            model.moveSelection(by: -1)
            return true
        case "Enter":
            if !model.selectedItems.isEmpty {
                let selected = model.items.filter { model.selectedItems.contains($0.id) }
                model.addMultipleToQueue(selected)
                NotificationCenter.default.post(name: .stashQueueAdd, object: selected.map(\.id))
                model.clearSelection()
            } else if let item = model.selectedItem {
                model.pasteItem(item.id)
            }
            return true
        case "Escape":
            if isInput { searchFocused = false }
            if !model.selectedItems.isEmpty {
                model.clearSelection()
            } else {
                onHide()
            }
            return true
        default:
            break
        }

        // ⌘1…⌘9 paste the n-th item.
        if info.metaKey, !info.ctrlKey, !info.altKey,
           let character = Shortcut.physicalKey(info).first, ("1"..."9").contains(String(character)) {
            let index = Int(String(character))! - 1
            if model.items.indices.contains(index) {
                model.pasteItem(model.items[index].id)
                return true
            }
            return false
        }

        if Shortcut.matches(info, settings.addToQueueShortcut), !isInput || searchText.isEmpty || info.metaKey || info.ctrlKey || info.altKey {
            if let item = model.selectedItem {
                model.addToQueue(item)
                NotificationCenter.default.post(name: .stashQueueAdd, object: [item.id])
            }
            return true
        }

        // `d` deletes the selected item.
        if info.key == "d", !info.metaKey, !info.ctrlKey, !info.altKey {
            if isInput { return false }
            if let item = model.selectedItem {
                model.deleteItem(item.id)
            }
            return true
        }

        // Panel shortcuts. The order matches the previous build, so a
        // conflicting configuration behaves the same way.
        if Shortcut.matches(info, settings.openSettingsShortcut) {
            onOpenSettings()
            return true
        }
        if Shortcut.matches(info, settings.toggleFilterShortcut) {
            model.toggleFilters()
            return true
        }
        if Shortcut.matches(info, settings.togglePreviewShortcut) {
            model.togglePreview()
            return true
        }
        if Shortcut.matches(info, settings.openTagShortcut) {
            if !isInput, model.tagPickerItemId == nil, let item = model.selectedItem {
                model.openTagPicker(for: item.id)
                return true
            }
            return false
        }

        // Any printable character moves the focus into the search field.
        if !isInput, !info.metaKey, !info.ctrlKey, !info.altKey,
           info.key.count == 1,
           let character = info.key.first,
           character.isASCII, character.isLetter || character.isNumber {
            searchText += event.characters ?? info.key
            searchFocused = true
            return true
        }
        return false
    }

    /// Builds the shortcut matcher input for an event.
    ///
    /// A modifier press arrives as a `flagsChanged` event without a character,
    /// so the modifier itself is used as the key. That way a modifier only
    /// shortcut such as "Alt" can be matched.
    static func keyInfo(for event: NSEvent) -> KeyEventInfo {
        NativeKeyboard.info(for: event)
    }

}

// MARK: - Notifications

public extension Notification.Name {
    /// Posted when items should be appended to the paste queue.
    static let stashQueueAdd = Notification.Name("com.zpaste.app.queueAdd")
    /// Posted when the paste queue should be cleared.
    static let stashQueueClear = Notification.Name("com.zpaste.app.queueClear")
    /// Posted when the panel should be hidden.
    static let stashPanelHide = Notification.Name("com.zpaste.app.panelHide")
    /// Posted when the layout mode changed.
    static let stashLayoutModeChanged = Notification.Name("com.zpaste.app.layoutModeChanged")
    /// Posted when a new clipboard item was captured.
    static let stashNewItem = Notification.Name("com.zpaste.app.newItem")
    /// Posted when the widget should refresh.
    static let stashWidgetRefresh = Notification.Name("com.zpaste.app.widgetRefresh")
}
