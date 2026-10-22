import StashCore
import SwiftUI

/// The vertical list of clipboard items.
public struct ClipboardListView: View {
    @ObservedObject var model: PanelViewModel
    public let theme: StashTheme
    @ObservedObject var iconStore: AppIconStore

    public init(model: PanelViewModel, theme: StashTheme, iconStore: AppIconStore) {
        self.model = model
        self.theme = theme
        self.iconStore = iconStore
    }

    public var body: some View {
        Group {
            if model.items.isEmpty {
                EmptyStateView(theme: theme, isFiltered: !model.searchQuery.isEmpty || model.filterType != nil || !model.leftFilter.isAll || model.sourceAppFilter != nil)
            } else {
                list
            }
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        ClipboardRowView(
                            item: item,
                            index: index,
                            isSelected: model.selectedIndex == index,
                            isMultiSelected: model.isItemSelected(item.id),
                            queuePosition: model.isItemInQueue(item.id) ? model.queuePosition(for: item.id) : 0,
                            model: model,
                            theme: theme,
                            iconStore: iconStore
                        )
                        .id(item.id)
                        .onAppear {
                            // Load the next page when the last row appears.
                            if index == model.items.count - 1 {
                                model.loadNextPage()
                            }
                        }
                    }

                    if model.isLoadingMore {
                        Text(L10n.t("panel.loadingMore"))
                            .font(.system(size: 11))
                            .foregroundColor(theme.mutedForeground)
                            .padding(.vertical, 14)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
            }
            .onChange(of: model.selectedIndex) { index in
                guard model.items.indices.contains(index) else { return }
                withAnimation(.none) {
                    proxy.scrollTo(model.items[index].id, anchor: nil)
                }
            }
        }
    }
}

/// A single row of the clipboard list.
struct ClipboardRowView: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let isMultiSelected: Bool
    let queuePosition: Int

    @ObservedObject var model: PanelViewModel
    let theme: StashTheme
    @ObservedObject var iconStore: AppIconStore

    @State var isHovering = false
    @State var isEditingTitle = false
    @State var titleDraft = ""
    @FocusState var titleFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            leadingIndicator

            VStack(alignment: .leading, spacing: 3) {
                titleLine
                contentLine
                metaLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingIndicators
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                model.setSelectedIndex(index)
            }
        }
        .gesture(
            TapGesture(count: 2).exclusively(before: TapGesture(count: 1)).onEnded { result in
                switch result {
                case .first: openEditor()
                case .second:
                    if NSEvent.modifierFlags.contains(.command) {
                        model.toggleSelectItem(item.id)
                    } else {
                        model.pasteItem(item.id)
                    }
                }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.displayPreview)
        .contextMenu {
            Button {
                beginTitleEditing()
            } label: {
                Label(L10n.t("panel.context.editTitle"), systemImage: Symbols.pencil)
            }
            Divider()
            Button(role: .destructive) {
                model.deleteItem(item.id)
            } label: {
                Label(L10n.t("panel.context.delete"), systemImage: Symbols.trash)
            }
        }
    }

    // MARK: - Pieces

    /// The preview, the content or the type label, in that order.
    private var rowText: String {
        if let preview = item.preview, !preview.isEmpty { return preview }
        if !item.content.isEmpty { return item.content }
        if let type = ContentType(rawValue: item.contentType) {
            return L10n.t(type.localizationKey)
        }
        return item.contentType
    }

    private var rowBackground: Color {
        if isMultiSelected { return theme.accentColor.opacity(0.14) }
        if isSelected { return theme.accentColor.opacity(theme.isDark ? 0.16 : 0.10) }
        if isHovering { return theme.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.035) }
        return Color.clear
    }

    private var borderColor: Color {
        if isMultiSelected { return theme.accentColor.opacity(0.40) }
        if isSelected { return Color.clear }
        return Color.clear
    }

    @ViewBuilder
    private var leadingIndicator: some View {
        if index < 9 {
            Text("⌘\(index + 1)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(isSelected ? theme.accentColor : theme.mutedForeground)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? theme.accentColor.opacity(0.15) : (theme.isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)))
                )
                .frame(width: 30)
        } else {
            Image(systemName: Symbols.contentType(item.contentType))
                .font(.system(size: 11))
                .foregroundColor(theme.mutedForeground)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.muted))
        }
    }

    @ViewBuilder
    private var titleLine: some View {
        if isEditingTitle {
            TextField(L10n.t("panel.title.placeholder"), text: $titleDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.accentColor)
                .focused($titleFocused)
                .onSubmit { commitTitle() }
                .onExitCommand { cancelTitleEditing() }
                .onChange(of: titleFocused) { focused in
                    // Losing the focus saves the title, like the old build.
                    if !focused, isEditingTitle { commitTitle() }
                }
        } else if let title = item.title, !title.isEmpty {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.accentColor)
                .lineLimit(1)
                .onTapGesture(count: 2) { beginTitleEditing() }
        }
    }

    @ViewBuilder
    private var contentLine: some View {
        if item.contentType == ContentType.image.rawValue {
            ImageRowContent(item: item, model: model, theme: theme)
        } else {
            Text(rowText)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(theme.foreground)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var metaLine: some View {
        if item.contentType == ContentType.image.rawValue {
            HStack(spacing: 5) {
                TypeChip(type: item.contentType, theme: theme)
                Text("•").foregroundColor(theme.mutedForeground)
                Text(RelativeTime.format(timestamp: item.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(theme.mutedForeground)
            }
        } else {
            HStack(spacing: 5) {
                TypeChip(type: item.contentType, theme: theme)
                Text("•").foregroundColor(theme.mutedForeground)
                Text(RelativeTime.format(timestamp: item.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(theme.mutedForeground)
                if item.useCount > 0 {
                    Text("•").foregroundColor(theme.mutedForeground)
                    Text(L10n.t("panel.item.useCount", ["count": String(item.useCount)]))
                        .font(.system(size: 10))
                        .foregroundColor(theme.mutedForeground)
                }
                if let sourceApp = item.sourceAppInfo {
                    Text("•").foregroundColor(theme.mutedForeground)
                    if let icon = iconStore.icon(for: sourceApp.bundleId) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                            .help(sourceApp.name)
                    } else {
                        Text(sourceApp.name)
                            .font(.system(size: 10))
                            .foregroundColor(theme.mutedForeground)
                            .lineLimit(1)
                            .frame(maxWidth: 96, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var trailingIndicators: some View {
        if isHovering {
            HStack(spacing: 2) {
                iconButton(Symbols.tag, L10n.t("panel.context.tag")) {
                    model.openTagPicker(for: item.id)
                }
                iconButton(Symbols.pin, item.isPinned ? L10n.t("panel.context.unpin") : L10n.t("panel.context.pin")) {
                    model.togglePin(item.id)
                }
                iconButton(Symbols.star, item.isFavorite ? L10n.t("panel.context.unfavorite") : L10n.t("panel.context.favorite")) {
                    model.toggleFavorite(item.id)
                }
            }
            .frame(minWidth: 64, alignment: .trailing)
        } else {
            HStack(spacing: 4) {
                if queuePosition > 0 {
                    Text("\(queuePosition)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(theme.accentForeground)
                        .frame(width: 15, height: 15)
                        .background(Circle().fill(theme.accentColor))
                }
                if item.isPinned {
                    Image(systemName: Symbols.pin)
                        .font(.system(size: 10))
                        .foregroundColor(theme.accentColor)
                }
                if item.isFavorite {
                    Image(systemName: Symbols.star)
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                }
                if item.tagSlugs?.isEmpty == false {
                    Image(systemName: Symbols.tag)
                        .font(.system(size: 10))
                        .foregroundColor(theme.accentColor)
                }
            }
            .frame(minWidth: 64, alignment: .trailing)
        }
    }

    private func iconButton(_ symbol: String, _ tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundColor(theme.mutedForeground)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    // MARK: - Title editing

    private func beginTitleEditing() {
        titleDraft = item.title ?? ""
        isEditingTitle = true
        model.isEditingTitle = true
        DispatchQueue.main.async { titleFocused = true }
    }

    private func commitTitle() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespaces)
        model.updateTitle(item.id, title: trimmed.isEmpty ? nil : trimmed)
        isEditingTitle = false
        model.isEditingTitle = false
    }

    private func cancelTitleEditing() {
        isEditingTitle = false
        model.isEditingTitle = false
    }

    /// The editor opens with the content of the item, like the old build.
    private func openEditor() {
        Task { @MainActor in
            _ = await model.loadItemContent(item.id)
            model.openEditor(for: item.id)
        }
    }
}

/// The thumbnail used for image items.
struct ImageRowContent: View {
    let item: ClipboardItem
    @ObservedObject var model: PanelViewModel
    let theme: StashTheme
    @StateObject private var loader = ImageLoader()

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let image = loader.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: Symbols.contentType(ContentType.image.rawValue))
                        .font(.system(size: 14))
                        .foregroundColor(theme.mutedForeground)
                }
            }
            .frame(width: 72, height: 48)
            .background(theme.muted)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )

            Text(item.preview ?? L10n.t("panel.image.fallback"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.foreground)
                .lineLimit(1)
        }
        .task {
            let content = await model.loadItemContent(item.id) ?? item.content
            loader.load(content: content, key: item.contentHash)
        }
    }
}
