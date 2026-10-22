import SwiftUI
import StashCore

/// SF Symbol names used across the app.
public enum Symbols {
    public static func contentType(_ type: String) -> String {
        switch type {
        case ContentType.text.rawValue: return "doc.text"
        case ContentType.code.rawValue: return "chevron.left.forwardslash.chevron.right"
        case ContentType.url.rawValue: return "link"
        case ContentType.json.rawValue: return "curlybraces"
        case ContentType.color.rawValue: return "paintpalette"
        case ContentType.image.rawValue: return "photo"
        case ContentType.base64.rawValue: return "lock"
        case ContentType.filePath.rawValue: return "doc"
        default: return "doc.text"
        }
    }

    public static let help = "questionmark.circle"
    public static let settings = "gearshape"
    public static let search = "magnifyingglass"
    public static let clear = "xmark.circle.fill"
    public static let close = "xmark"
    public static let tag = "tag"
    public static let pin = "pin"
    public static let star = "star"
    public static let trash = "trash"
    public static let pencil = "pencil"
    public static let list = "list.bullet"
    public static let cards = "square.grid.2x2"
    public static let chevronLeft = "chevron.left"
    public static let chevronRight = "chevron.right"
    public static let sort = "arrow.up.arrow.down"
    public static let copy = "doc.on.doc"
    public static let download = "arrow.down.circle"
    public static let rotate = "arrow.clockwise"
    public static let check = "checkmark"
    public static let checkCircle = "checkmark.circle.fill"
    public static let warning = "exclamationmark.triangle.fill"
    public static let info = "info.circle"
    public static let cloud = "cloud"
    public static let lockShield = "lock.shield"
    public static let keyboard = "keyboard"
    public static let grid = "square.grid.2x2"
    public static let palette = "paintpalette"
    public static let clock = "clock"
    public static let sync = "arrow.triangle.2.circlepath"
    public static let paste = "doc.on.clipboard"
    public static let plus = "plus"
    public static let merge = "arrow.triangle.merge"
    public static let eye = "eye"
    public static let sidebar = "sidebar.right"
    public static let expand = "arrow.right.to.line"
    public static let collapse = "arrow.left.to.line"
}

/// A small pill that shows a content type.
public struct TypeChip: View {
    public let type: String
    public let theme: StashTheme
    public var font: Font = .system(size: 9, weight: .semibold)

    public init(type: String, theme: StashTheme, font: Font = .system(size: 9, weight: .semibold)) {
        self.type = type
        self.theme = theme
        self.font = font
    }

    public var body: some View {
        Text(label.uppercased())
            .font(font)
            .tracking(0.6)
            .foregroundColor(theme.mutedForeground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.muted)
            )
    }

    private var label: String {
        let key = ContentType(rawValue: type)?.localizationKey
        guard let key else { return type }
        return L10n.t(key)
    }
}

/// A rounded, bordered container used for cards and panels.
public struct PanelContainer<Content: View>: View {
    private let theme: StashTheme
    private let cornerRadius: CGFloat
    private let content: Content

    public init(theme: StashTheme, cornerRadius: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
    }
}

/// A pill shaped button used for filters and badges.
public struct PillButton: View {
    private let title: String
    private let isActive: Bool
    private let theme: StashTheme
    private let action: () -> Void
    private var count: Int?
    private var icon: String?

    public init(
        title: String,
        isActive: Bool,
        theme: StashTheme,
        count: Int? = nil,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isActive = isActive
        self.theme = theme
        self.count = count
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .medium))
                        .opacity(0.7)
                }
            }
            .foregroundColor(isActive ? theme.accentForeground : theme.mutedForeground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? theme.accentColor : theme.muted)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isActive ? Color.clear : theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// A square toggle button used in the panel header.
public struct SquareToggleButton: View {
    private let title: String
    private let isActive: Bool
    private let theme: StashTheme
    private let action: () -> Void

    public init(title: String, isActive: Bool, theme: StashTheme, action: @escaping () -> Void) {
        self.title = title
        self.isActive = isActive
        self.theme = theme
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isActive ? theme.accentForeground : theme.mutedForeground)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(isActive ? theme.accentColor : theme.muted)
                )
        }
        .buttonStyle(.plain)
    }
}

/// The application logo used in the panel header.
public struct AppLogoView: View {
    private let size: CGFloat

    public init(size: CGFloat = 28) {
        self.size = size
    }

    static var iconURL: URL? {
        let packaged = Bundle.main.resourceURL?.appendingPathComponent("Stash_StashUI.bundle/Resources/icon.png")
        if let packaged, FileManager.default.fileExists(atPath: packaged.path) { return packaged }
        guard Bundle.main.bundleURL.pathExtension != "app" else { return nil }
        return Bundle.module.url(forResource: "icon", withExtension: "png", subdirectory: "Resources")
    }

    public var body: some View {
        Group {
            if let url = Self.iconURL,
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "tray.full")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(3)
            }
        }
        .frame(width: size, height: size)
    }
}
