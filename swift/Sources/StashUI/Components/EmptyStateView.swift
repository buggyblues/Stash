import SwiftUI

/// The empty state of the clipboard list.
public struct EmptyStateView: View {
    public let theme: StashTheme
    public var isFiltered: Bool

    public init(theme: StashTheme, isFiltered: Bool = false) {
        self.theme = theme
        self.isFiltered = isFiltered
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isFiltered ? "magnifyingglass" : "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(theme.mutedForeground)
                .padding(.bottom, 6)
            Text(L10n.t(isFiltered ? "panel.empty.filteredTitle" : "panel.empty.title"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.foreground)
            Text(L10n.t(isFiltered ? "panel.empty.filteredSubtitle" : "panel.empty.subtitle"))
                .font(.system(size: 11))
                .foregroundColor(theme.mutedForeground)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
