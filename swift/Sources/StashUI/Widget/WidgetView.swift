import AppKit
import StashCore
import SwiftUI

/// The floating desktop widget.
public struct WidgetView: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject public var model: WidgetViewModel
    @ObservedObject public var settings: SettingsStore
    private var theme: StashTheme {
        StashTheme(resolved: settings.resolvedTheme, accentHex: settings.accentColor)
    }

    public init(model: WidgetViewModel, settings: SettingsStore) {
        self.model = model
        self.settings = settings
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.border.opacity(0.4))

            if model.items.isEmpty {
                Text(L10n.t("widget.empty"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.mutedForeground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        row(item, index: index)
                        if index < model.items.count - 1 {
                            Divider().overlay(theme.border.opacity(0.35))
                        }
                    }
                }
            }
        }
        .stashGlassSurface(cornerRadius: 18)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(StashWindowAppearance().frame(width: 0, height: 0))
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .tint(theme.accentColor)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.accentColor)
            Text(L10n.t("widget.title"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.foreground)
            Spacer()
            Button {
                model.togglePin()
            } label: {
                Image(systemName: model.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11))
                    .foregroundColor(model.isPinned ? theme.accentColor : theme.mutedForeground)
            }
            .buttonStyle(.plain)
            .help(model.isPinned ? L10n.t("panel.context.unpin") : L10n.t("panel.context.pin"))
            Button {
                model.close()
            } label: {
                Image(systemName: Symbols.close)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.mutedForeground)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Color.white.opacity(0.04))
        .background(DragRegion())
    }

    // MARK: - Rows

    private func row(_ item: ClipboardItem, index: Int) -> some View {
        Button {
            model.paste(item)
        } label: {
            HStack(spacing: 7) {
                Text(Shortcut.display(settings.widgetQuickPastePrefix) + "\(index + 1)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.mutedForeground)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(theme.cardElevated.opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(theme.border.opacity(0.5), lineWidth: 0.5)
                    )

                if item.contentType == ContentType.image.rawValue {
                    WidgetThumbnail(item: item, model: model)
                }

                Text(text(for: item))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(theme.foreground)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: Symbols.contentType(item.contentType))
                    .font(.system(size: 10))
                    .foregroundColor(theme.mutedForeground)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func text(for item: ClipboardItem) -> String {
        if item.contentType == ContentType.image.rawValue {
            return item.preview ?? L10n.t("widget.imageFallback")
        }
        let source = item.preview ?? item.content
        return source.count > 40 ? String(source.prefix(40)) + "…" : source
    }
}

/// The thumbnail shown for image items in the widget.
struct WidgetThumbnail: View {
    let item: ClipboardItem
    @ObservedObject var model: WidgetViewModel
    @StateObject private var loader = ImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: Symbols.contentType(ContentType.image.rawValue))
                    .font(.system(size: 10))
                    .foregroundColor(themeColor)
            }
        }
        .frame(width: 48, height: 32)
        .background(themeColor.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .task {
            let content = await model.loadContent(item.id) ?? item.content
            loader.load(content: content, key: item.contentHash)
        }
    }

    private var themeColor: Color { .secondary }
}

/// The state of the desktop widget.
@MainActor
public final class WidgetViewModel: ObservableObject {
    @Published public private(set) var items: [ClipboardItem] = []
    @Published public private(set) var isPinned = true

    private let repository: Repository
    private var filter: WidgetFilter = WidgetFilter()
    private var followFilter = false

    public var onPaste: ((ClipboardItem) -> Void)?
    public var onClose: (() -> Void)?

    public init(repository: Repository) {
        self.repository = repository
    }

    /// The filter the panel shared with the widget.
    public struct WidgetFilter: Equatable {
        public var contentType: String?
        public var leftFilter: LeftFilter
        public var sourceApp: String?
        public var sortBy: SortBy

        public init(
            contentType: String? = nil,
            leftFilter: LeftFilter = .all,
            sourceApp: String? = nil,
            sortBy: SortBy = .recent
        ) {
            self.contentType = contentType
            self.leftFilter = leftFilter
            self.sourceApp = sourceApp
            self.sortBy = sortBy
        }
    }

    public func setFilter(_ filter: WidgetFilter) {
        self.filter = filter
    }

    public func setFollowFilter(_ value: Bool) {
        followFilter = value
    }

    public func togglePin() {
        isPinned.toggle()
        onPinnedChanged?(isPinned)
    }

    /// Called when the pin state changes.
    public var onPinnedChanged: ((Bool) -> Void)?

    public func close() {
        onClose?()
    }

    public func load() {
        let options: GetItemsOptions
        if followFilter {
            options = GetItemsOptions(
                limit: 5,
                contentType: filter.contentType,
                leftFilter: filter.leftFilter,
                sourceApp: filter.sourceApp,
                sortBy: filter.sortBy
            )
        } else {
            options = GetItemsOptions(limit: 5)
        }
        items = (try? repository.getItems(options: options)) ?? []
    }

    public func paste(_ item: ClipboardItem) {
        onPaste?(item)
    }

    public func loadContent(_ id: String) async -> String? {
        let repository = self.repository
        let result = await Task.detached(priority: .userInitiated) {
            try? repository.getItemContent(id)
        }.value
        return result?.content
    }
}
