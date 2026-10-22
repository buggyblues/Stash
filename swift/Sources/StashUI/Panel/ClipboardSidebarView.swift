import StashCore
import SwiftUI

/// A single navigation layer over the window's native glass surface.
struct ClipboardSidebarView: View {
    @ObservedObject var model: PanelViewModel
    let theme: StashTheme
    @ObservedObject var iconStore: AppIconStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                heading("panel.navigation.library")
                row(L10n.t("panel.sidebar.all"), icon: "tray.full", active: model.leftFilter.isAll) {
                    model.setLeftFilter(.all)
                }
                if !model.tagBarCollapsed {
                    row(L10n.t("panel.sidebar.starred"), icon: "star", active: model.leftFilter.isStarred,
                        count: model.starredCount) { model.setLeftFilter(.starred) }
                    ForEach(model.tags) { tag in
                        row(tag.name, icon: "tag", active: model.leftFilter.slug == tag.slug, count: tag.count) {
                            model.setLeftFilter(model.leftFilter.slug == tag.slug ? .all : .tag(slug: tag.slug))
                        }
                    }
                }
                if !model.typeFilterCollapsed {
                    heading("panel.navigation.types")
                    row(L10n.t("common.all"), icon: "square.grid.2x2", active: false) {
                        model.setFilterType(nil)
                    }
                    ForEach(ContentType.filterOrder, id: \.rawValue) { type in
                        row(L10n.t(type.localizationKey), icon: Symbols.contentType(type.rawValue),
                            active: model.filterType == type.rawValue, count: model.typeCounts[type.rawValue]) {
                            model.setFilterType(model.filterType == type.rawValue ? nil : type.rawValue)
                        }
                    }
                }
                if !model.sourceAppFilterCollapsed && !model.sourceApps.isEmpty {
                    heading("panel.navigation.sources")
                    row(L10n.t("common.all"), icon: "app.dashed", active: false) {
                        model.setSourceAppFilter(nil)
                    }
                    ForEach(model.sourceApps) { source in
                        Button {
                            model.setSourceAppFilter(model.sourceAppFilter == source.bundleId ? nil : source.bundleId)
                        } label: {
                            HStack(spacing: 8) {
                                if let icon = iconStore.icon(for: source.bundleId) {
                                    Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "app").frame(width: 16)
                                }
                                Text(source.name).lineLimit(1)
                                Spacer(minLength: 2)
                                Text(String(source.count)).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            .sidebarRow(active: model.sourceAppFilter == source.bundleId, theme: theme)
                        }
                        .buttonStyle(.plain)
                        .help(source.name)
                        .disabled(source.bundleId.isEmpty)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 14)
        }
    }

    private func heading(_ key: String) -> some View {
        Text(L10n.t(key))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }

    private func row(_ title: String, icon: String, active: Bool, count: Int? = nil,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundColor(theme.accentColor).frame(width: 16)
                Text(title).lineLimit(1)
                Spacer(minLength: 2)
                if let count, count > 0 {
                    Text(String(count)).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .sidebarRow(active: active, theme: theme)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

private extension View {
    func sidebarRow(active: Bool, theme: StashTheme) -> some View {
        self.font(.system(size: 12))
            .foregroundColor(theme.foreground)
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(active ? theme.accentColor.opacity(theme.isDark ? 0.22 : 0.14) : .clear,
                        in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}

/// Compact layouts use semantic native menus instead of horizontally clipped filter rows.
struct CompactFilterBar: View {
    @ObservedObject var model: PanelViewModel
    let theme: StashTheme

    var body: some View {
        HStack(spacing: 8) {
            if !model.tagBarCollapsed {
                Menu {
                    Button(L10n.t("common.all")) { model.setLeftFilter(.all) }
                    Button(L10n.t("panel.sidebar.starred")) { model.setLeftFilter(.starred) }
                    ForEach(model.tags) { tag in
                        Button(tag.name) { model.setLeftFilter(.tag(slug: tag.slug)) }
                    }
                } label: {
                    Label(collectionTitle, systemImage: model.leftFilter.isStarred ? "star" : "tray")
                }
            }
            if !model.typeFilterCollapsed {
                Menu {
                    Button(L10n.t("common.all")) { model.setFilterType(nil) }
                    ForEach(ContentType.filterOrder, id: \.rawValue) { type in
                        Button(L10n.t(type.localizationKey)) { model.setFilterType(type.rawValue) }
                    }
                } label: {
                    Label(typeTitle, systemImage: "line.3.horizontal.decrease")
                }
            }
            if !model.sourceAppFilterCollapsed {
                Menu {
                    Button(L10n.t("common.all")) { model.setSourceAppFilter(nil) }
                    ForEach(model.sourceApps) { source in
                        Button(source.name) { model.setSourceAppFilter(source.bundleId) }
                            .disabled(source.bundleId.isEmpty)
                    }
                } label: {
                    Label(sourceTitle, systemImage: "app")
                }
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 11))
        .controlSize(.small)
    }

    private var collectionTitle: String {
        if model.leftFilter.isStarred { return L10n.t("panel.sidebar.starred") }
        return model.tags.first { $0.slug == model.leftFilter.slug }?.name ?? L10n.t("common.all")
    }
    private var typeTitle: String {
        model.filterType.flatMap(ContentType.init(rawValue:)).map { L10n.t($0.localizationKey) }
            ?? L10n.t("panel.navigation.types")
    }
    private var sourceTitle: String {
        model.sourceApps.first { $0.bundleId == model.sourceAppFilter }?.name ?? L10n.t("panel.navigation.sources")
    }
}
