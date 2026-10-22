import AppKit
import StashCore
import SwiftUI

/// The detail panel shown next to the clipboard list.
public struct PreviewPanelView: View {
    let item: ClipboardItem
    @ObservedObject var model: PanelViewModel
    public let theme: StashTheme
    var onToggleCollapse: () -> Void

    @StateObject private var contentLoader = ContentLoader()

    public init(
        item: ClipboardItem,
        model: PanelViewModel,
        theme: StashTheme,
        onToggleCollapse: @escaping () -> Void
    ) {
        self.item = item
        self.model = model
        self.theme = theme
        self.onToggleCollapse = onToggleCollapse
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(theme.border)
            ScrollView {
                previewBody
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            toolbar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(theme.card)
        .task(id: item.id) {
            contentLoader.set(nil)
            let loaded = await model.loadItemContent(item.id)
            guard !Task.isCancelled else { return }
            contentLoader.set(loaded)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundColor(theme.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(theme.accentColor.opacity(0.14))
                )

            if let title = item.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.foreground)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if item.useCount > 0 {
                Text(L10n.t("preview.useCount", ["count": String(item.useCount)]))
                    .font(.system(size: 10))
                    .foregroundColor(theme.mutedForeground)
            }

            Text(timestampText)
                .font(.system(size: 10))
                .foregroundColor(theme.mutedForeground)

            Button(action: onToggleCollapse) {
                Image(systemName: Symbols.collapse)
                    .font(.system(size: 11))
                    .foregroundColor(theme.mutedForeground)
            }
            .buttonStyle(.plain)
            .help(L10n.t("preview.collapseDetails") + " (⌥)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var label: String {
        guard let type = ContentType(rawValue: item.contentType) else { return item.contentType }
        return L10n.t(type.localizationKey)
    }

    private var timestampText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: Double(item.createdAt) / 1000))
    }

    // MARK: - Body

    @ViewBuilder
    private var previewBody: some View {
        let text = contentLoader.content ?? ""
        switch item.contentType {
        case ContentType.code.rawValue:
            CodePreviewView(
                code: text,
                language: (item.metadataDictionary["language"] as? String) ?? "plaintext",
                theme: theme
            )
        case ContentType.json.rawValue:
            JsonPreviewView(content: text, theme: theme, showsHeader: true)
        case ContentType.color.rawValue:
            ColorPreviewView(content: text, theme: theme)
        case ContentType.image.rawValue:
            ImagePreviewView(content: text, metadata: item.metadata, theme: theme)
        default:
            Text(text)
                .font(.system(size: 13, design: item.contentType == ContentType.text.rawValue ? .default : .monospaced))
                .foregroundColor(theme.foreground)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Toolbars

    @ViewBuilder
    private var toolbar: some View {
        let text = contentLoader.content ?? ""
        switch item.contentType {
        case ContentType.text.rawValue:
            TextToolbar(content: text, theme: theme)
        case ContentType.base64.rawValue:
            Base64Toolbar(content: text, theme: theme)
        case ContentType.url.rawValue:
            UrlToolbar(content: text, theme: theme)
        default:
            EmptyView()
        }
    }
}

/// The eight text transformations.
struct TextToolbar: View {
    let content: String
    let theme: StashTheme

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(Transformers.all, id: \.key) { transformation in
                Button {
                    PasteServiceBridge.shared.writeText(transformation.transform(content))
                } label: {
                    Text(L10n.t(transformation.labelKey))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.mutedForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(theme.muted)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The Base64 expansion toolbar.
struct Base64Toolbar: View {
    let content: String
    let theme: StashTheme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(theme.mutedForeground)
                }
                .buttonStyle(.plain)

                Text(isExpanded ? L10n.t("preview.collapseDecoded") : L10n.t("preview.expandDecoded"))
                    .font(.system(size: 10))
                    .foregroundColor(theme.mutedForeground)

                Spacer()

                if isExpanded, decoded.valid {
                    Button {
                        PasteServiceBridge.shared.writeText(decoded.decoded)
                    } label: {
                        Text(L10n.t("preview.copy"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isExpanded {
                Text(decoded.valid ? decoded.decoded : L10n.t("preview.invalidBase64"))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(decoded.valid ? theme.foreground : theme.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .frame(maxHeight: 96, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(theme.muted)
                    )
            }
        }
    }

    private var decoded: Formatters.Base64Result {
        Formatters.decodeBase64(content)
    }
}

/// The URL toolbar.
struct UrlToolbar: View {
    let content: String
    let theme: StashTheme

    var body: some View {
        HStack(spacing: 10) {
            Button {
                PasteServiceBridge.shared.writeText(content)
            } label: {
                Label(L10n.t("preview.copyUrl"), systemImage: Symbols.copy)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.accentColor)
            }
            .buttonStyle(.plain)

            if decoded != content {
                Button {
                    PasteServiceBridge.shared.writeText(decoded)
                } label: {
                    Label(L10n.t("preview.copyDecoded"), systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var decoded: String {
        Formatters.decodeURL(content)
    }
}

/// The empty state of the preview panel.
public struct PreviewEmptyView: View {
    public let theme: StashTheme

    public init(theme: StashTheme) {
        self.theme = theme
    }

    public var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 30))
                .foregroundColor(theme.foreground.opacity(0.2))
            Text(L10n.t("preview.selectItem"))
                .font(.system(size: 12))
                .foregroundColor(theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Writes text to the system pasteboard from the UI layer.
final class PasteServiceBridge {
    static let shared = PasteServiceBridge()

    func writeText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
