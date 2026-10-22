import StashCore
import SwiftUI

/// The horizontal badge row with the "all"/"inbox" filter, the sort toggle and
/// the user's tags.
public struct TagBarView: View {
    @ObservedObject var model: PanelViewModel
    public let theme: StashTheme

    public init(model: PanelViewModel, theme: StashTheme) {
        self.model = model
        self.theme = theme
    }

    public var body: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    PillButton(
                        title: L10n.t("common.all"),
                        isActive: model.leftFilter.isAll,
                        theme: theme
                    ) {
                        model.setLeftFilter(.all)
                    }

                    PillButton(
                        title: L10n.t("panel.tagBar.starred"),
                        isActive: model.leftFilter.isStarred,
                        theme: theme,
                        count: model.starredCount,
                        icon: "star"
                    ) {
                        model.setLeftFilter(model.leftFilter.isStarred ? .all : .starred)
                    }

                    PillButton(
                        title: L10n.t("panel.filter.byUsage"),
                        isActive: model.sortBy == .usage,
                        theme: theme,
                        icon: Symbols.sort
                    ) {
                        model.setSortBy(model.sortBy == .usage ? .recent : .usage)
                    }

                    if !model.tags.isEmpty {
                        Rectangle()
                            .fill(theme.border)
                            .frame(width: 1, height: 14)
                            .padding(.horizontal, 2)
                    }

                    ForEach(model.tags) { tag in
                        PillButton(
                            title: tag.name,
                            isActive: model.leftFilter.slug == tag.slug,
                            theme: theme,
                            count: tag.count,
                            icon: "tag"
                        ) {
                            if model.leftFilter.slug == tag.slug {
                                model.setLeftFilter(.all)
                            } else {
                                model.setLeftFilter(.tag(slug: tag.slug))
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
        }
        .background(theme.card.opacity(0.6))
        .overlay(Rectangle().fill(theme.border).frame(height: 1), alignment: .bottom)
    }
}

/// The type filter tabs and the source application filter.
public struct FilterTabsView: View {
    @ObservedObject var model: PanelViewModel
    public let theme: StashTheme
    @ObservedObject var iconStore: AppIconStore

    public init(model: PanelViewModel, theme: StashTheme, iconStore: AppIconStore) {
        self.model = model
        self.theme = theme
        self.iconStore = iconStore
    }

    private struct TypeOption: Identifiable {
        let id: String
        let rawValue: String?
        let label: String
    }

    private var typeOptions: [TypeOption] {
        var options = [TypeOption(id: "all", rawValue: nil, label: L10n.t("panel.filter.all"))]
        for type in ContentType.filterOrder {
            options.append(
                TypeOption(id: type.rawValue, rawValue: type.rawValue, label: L10n.t(type.localizationKey))
            )
        }
        return options
    }

    public var body: some View {
        let showTypeFilter = !model.typeFilterCollapsed
        let showSourceApps = !model.sourceAppFilterCollapsed && !model.sourceApps.isEmpty

        if showTypeFilter || showSourceApps {
            VStack(spacing: 0) {
                if showTypeFilter {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(typeOptions) { option in
                                PillButton(
                                    title: option.label,
                                    isActive: model.filterType == option.rawValue,
                                    theme: theme,
                                    count: option.rawValue.map { model.typeCounts[$0] ?? 0 } ?? 0
                                ) {
                                    model.setFilterType(option.rawValue)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                }

                if showSourceApps {
                    Rectangle().fill(theme.border).frame(height: 1)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            PillButton(
                                title: L10n.t("panel.filter.all"),
                                isActive: model.sourceAppFilter == nil,
                                theme: theme
                            ) {
                                model.setSourceAppFilter(nil)
                            }

                            ForEach(model.sourceApps) { app in
                                Button {
                                    model.setSourceAppFilter(model.sourceAppFilter == app.bundleId ? nil : app.bundleId)
                                } label: {
                                    HStack(spacing: 5) {
                                        if let icon = iconStore.icon(for: app.bundleId) {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .frame(width: 14, height: 14)
                                        }
                                        Text(app.name)
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                            .frame(maxWidth: 90, alignment: .leading)
                                        Text("\(app.count)")
                                            .font(.system(size: 9, weight: .medium))
                                            .opacity(0.7)
                                    }
                                    .foregroundColor(model.sourceAppFilter == app.bundleId
                                                     ? theme.accentForeground
                                                     : theme.mutedForeground)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(model.sourceAppFilter == app.bundleId ? theme.accentColor : theme.muted)
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(model.sourceAppFilter == app.bundleId
                                                    ? Color.clear
                                                    : theme.border,
                                                    lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(app.bundleId.isEmpty)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                }
            }
            .background(theme.card.opacity(0.35))
            .overlay(Rectangle().fill(theme.border).frame(height: 1), alignment: .bottom)
        }
    }
}
