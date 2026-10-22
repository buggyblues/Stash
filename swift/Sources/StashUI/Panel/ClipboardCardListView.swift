import StashCore
import SwiftUI

/// The horizontal card carousel used by the "bottom" layout.
public struct ClipboardCardListView: View {
    @ObservedObject var model: PanelViewModel
    public let theme: StashTheme
    @ObservedObject var iconStore: AppIconStore

    private let cardWidth: CGFloat = 280
    private let cardGap: CGFloat = 12

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
                carousel
            }
        }
    }

    private var carousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: cardGap) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        ClipboardCardView(
                            item: item,
                            index: index,
                            isSelected: model.selectedIndex == index,
                            isMultiSelected: model.isItemSelected(item.id),
                            queuePosition: model.isItemInQueue(item.id) ? model.queuePosition(for: item.id) : 0,
                            model: model,
                            theme: theme,
                            iconStore: iconStore
                        )
                        .frame(width: cardWidth)
                        .id(item.id)
                        .onAppear {
                            if index == model.items.count - 1 { model.loadNextPage() }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .onChange(of: model.selectedIndex) { index in
                guard model.items.indices.contains(index) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(model.items[index].id, anchor: nil)
                }
            }
        }
    }
}

/// A single card of the carousel.
struct ClipboardCardView: View {
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
    @StateObject private var contentLoader = ContentLoader()
    @FocusState var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(theme.border)
            body_
            Divider().overlay(theme.border)
            footer
        }
        .frame(maxHeight: .infinity)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? theme.accentColor.opacity(0.5) : theme.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering { model.setSelectedIndex(index) }
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
                model.openTagPicker(for: item.id)
            } label: {
                Label(L10n.t("panel.context.tag"), systemImage: Symbols.tag)
            }
            Button {
                model.togglePin(item.id)
            } label: {
                Label(item.isPinned ? L10n.t("panel.context.unpin") : L10n.t("panel.context.pin"),
                      systemImage: Symbols.pin)
            }
            Button {
                model.toggleFavorite(item.id)
            } label: {
                Label(item.isFavorite ? L10n.t("panel.context.unfavorite") : L10n.t("panel.context.favorite"),
                      systemImage: Symbols.star)
            }
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
        .task(id: item.id) {
            let loaded = await model.loadItemContent(item.id)
            await MainActor.run {
                contentLoader.set(loaded)
            }
        }
    }

    private func openEditor() {
        Task { @MainActor in
            _ = await model.loadItemContent(item.id)
            model.openEditor(for: item.id)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: Symbols.contentType(item.contentType))
                .font(.system(size: 10))
                .foregroundColor(theme.mutedForeground)
                .frame(width: 20, height: 20)
                .background(Circle().fill(theme.muted))

            if isEditingTitle {
                TextField(L10n.t("panel.title.placeholder"), text: $titleDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.foreground)
                    .focused($titleFocused)
                    .onSubmit { commitTitle() }
                    .onExitCommand { cancelTitleEditing() }
                    .onChange(of: titleFocused) { focused in
                        if !focused, isEditingTitle { commitTitle() }
                    }
            } else {
                Text(cardTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.foreground)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isHovering {
                HStack(spacing: 2) {
                    Button { model.openTagPicker(for: item.id) } label: {
                        Image(systemName: Symbols.tag).font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.mutedForeground)
                    .help(L10n.t("panel.context.tag"))

                    Button { model.togglePin(item.id) } label: {
                        Image(systemName: Symbols.pin).font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.mutedForeground)

                    Button { model.toggleFavorite(item.id) } label: {
                        Image(systemName: Symbols.star).font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.mutedForeground)
                }
            } else {
                HStack(spacing: 4) {
                    if queuePosition > 0 {
                        Text("\(queuePosition)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(theme.accentForeground)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(theme.accentColor))
                    }
                    if item.isPinned {
                        Image(systemName: Symbols.pin)
                            .font(.system(size: 9))
                            .foregroundColor(theme.accentColor)
                    }
                    if item.isFavorite {
                        Image(systemName: Symbols.star)
                            .font(.system(size: 9))
                            .foregroundColor(.yellow)
                    }
                    if item.tagSlugs?.isEmpty == false {
                        Image(systemName: Symbols.tag)
                            .font(.system(size: 9))
                            .foregroundColor(theme.accentColor)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private var body_: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                CardPreviewContent(item: item, content: contentLoader.content, theme: theme)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack(spacing: 5) {
            TypeChip(type: item.contentType, theme: theme)
            Text("•").font(.system(size: 9)).foregroundColor(theme.mutedForeground)
            Text(RelativeTime.format(timestamp: item.createdAt))
                .font(.system(size: 9))
                .foregroundColor(theme.mutedForeground)
            if item.useCount > 0 {
                Text("•").font(.system(size: 9)).foregroundColor(theme.mutedForeground)
                Text(L10n.t("panel.item.useCount", ["count": String(item.useCount)]))
                    .font(.system(size: 9))
                    .foregroundColor(theme.mutedForeground)
            }
            if let sourceApp = item.sourceAppInfo, let icon = iconStore.icon(for: sourceApp.bundleId) {
                Text("•").font(.system(size: 9)).foregroundColor(theme.mutedForeground)
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 11, height: 11)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    /// The title, the preview or the type label, in that order.
    private var cardTitle: String {
        if let title = item.title, !title.isEmpty { return title }
        if let preview = item.preview, !preview.isEmpty { return preview }
        if let type = ContentType(rawValue: item.contentType) {
            return L10n.t(type.localizationKey)
        }
        return item.contentType
    }

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
}

/// The type specific preview inside a card.
struct CardPreviewContent: View {
    let item: ClipboardItem
    let content: String?
    let theme: StashTheme

    var body: some View {
        Group {
            switch item.contentType {
            case ContentType.code.rawValue:
                CodePreviewView(code: content ?? "", language: (item.metadataDictionary["language"] as? String) ?? "plaintext", theme: theme)
            case ContentType.json.rawValue:
                JsonPreviewView(content: content ?? "", theme: theme, showsHeader: false)
            case ContentType.color.rawValue:
                ColorPreviewView(content: content ?? "", theme: theme)
            case ContentType.image.rawValue:
                ImagePreviewView(content: content ?? "", metadata: item.metadata, theme: theme)
            default:
                Text(content ?? item.preview ?? "")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(theme.foreground)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
