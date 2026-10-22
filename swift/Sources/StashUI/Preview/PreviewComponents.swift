import AppKit
import StashCore
import SwiftUI

/// The syntax highlighted code preview.
public struct CodePreviewView: View {
    let code: String
    let language: String
    public let theme: StashTheme

    public init(code: String, language: String, theme: StashTheme) {
        self.code = code
        self.language = language
        self.theme = theme
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(highlighted.enumerated()), id: \.offset) { _, line in
                    line.tokens.reduce(Text("")) { text, token in
                        text + Text(token.text).foregroundColor(theme.color(for: token.kind))
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .textSelection(.enabled)
    }

    private var highlighted: [SyntaxHighlighter.Line] {
        let resolved = SyntaxLanguage(detected: language)
        return SyntaxHighlighter.highlight(code, language: resolved)
    }
}

/// The JSON preview with the validity badge and the copy button.
public struct JsonPreviewView: View {
    let content: String
    public let theme: StashTheme
    var showsHeader: Bool = true

    public init(content: String, theme: StashTheme, showsHeader: Bool = true) {
        self.content = content
        self.theme = theme
        self.showsHeader = showsHeader
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsHeader {
                HStack(spacing: 10) {
                    Text(result.valid ? L10n.t("preview.json.valid") : L10n.t("preview.json.invalid"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(result.valid ? jsonStringColor : theme.destructive)
                    Spacer()
                    Button {
                        PasteServiceBridge.shared.writeText(result.formatted)
                    } label: {
                        Text(L10n.t("preview.copy"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView {
                if result.valid {
                    JSONColorizer.tokenize(result.formatted).reduce(Text("")) { text, fragment in
                        text + Text(fragment.text).foregroundColor(color(for: fragment.kind))
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                } else {
                    Text(result.formatted)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(theme.foreground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .frame(maxHeight: showsHeader ? 260 : .infinity)
        }
    }

    private var result: Formatters.JSONResult {
        Formatters.formatJSON(content)
    }

    private var jsonStringColor: Color {
        theme.isDark ? Color(red: 0.31, green: 0.63, blue: 0.31) : Color(red: 0.31, green: 0.63, blue: 0.31)
    }

    private func color(for kind: JSONColorizer.Fragment.Kind) -> Color {
        switch kind {
        case .key:
            return theme.isDark
                ? Color(red: 0.78, green: 0.65, blue: 0.98)
                : Color(hue: 0.74, saturation: 0.8, brightness: 0.5)
        case .string:
            return theme.isDark
                ? Color(red: 0.50, green: 0.82, blue: 0.60)
                : Color(hue: 0.40, saturation: 0.55, brightness: 0.35)
        case .number:
            return theme.isDark
                ? Color(red: 1.0, green: 0.72, blue: 0.42)
                : Color(hue: 0.09, saturation: 1.0, brightness: 0.50)
        case .boolean:
            return theme.isDark
                ? Color(red: 0.93, green: 0.80, blue: 0.46)
                : Color(hue: 0.14, saturation: 1.0, brightness: 0.45)
        case .null:
            return theme.isDark
                ? Color(red: 0.98, green: 0.55, blue: 0.60)
                : Color(hue: 0, saturation: 0.65, brightness: 0.50)
        case .punctuation:
            return theme.mutedForeground
        }
    }
}

/// The colour preview with the swatch and the HEX/RGB/HSL rows.
public struct ColorPreviewView: View {
    let content: String
    public let theme: StashTheme

    public init(content: String, theme: StashTheme) {
        self.content = content
        self.theme = theme
    }

    public var body: some View {
        if let color = ColorParser.parse(content) {
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: color.hex))
                    .frame(width: 96, height: 96)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(theme.isDark ? 0.4 : 0.12), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 6) {
                    colorRow("HEX", color.hexDisplay)
                    colorRow("RGB", color.rgbDisplay)
                    colorRow("HSL", color.hslDisplay)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(L10n.t("preview.colorParseError"))
                .font(.system(size: 11))
                .foregroundColor(theme.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func colorRow(_ label: String, _ value: String) -> some View {
        Button {
            PasteServiceBridge.shared.writeText(value)
        } label: {
            HStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.mutedForeground)
                    .frame(width: 34, alignment: .leading)
                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.foreground)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The image preview.
public struct ImagePreviewView: View {
    let content: String
    let metadata: String?
    public let theme: StashTheme
    @StateObject private var loader = ImageLoader()

    public init(content: String, metadata: String?, theme: StashTheme) {
        self.content = content
        self.metadata = metadata
        self.theme = theme
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let image = loader.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.muted)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 22))
                                .foregroundColor(theme.mutedForeground)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 256)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )

            if let size = imageSize {
                Text(caption(for: size))
                    .font(.system(size: 10))
                    .foregroundColor(theme.mutedForeground)
            }
        }
        .task(id: content) {
            loader.load(content: content, key: content)
        }
    }

    private var imageSize: (width: Int, height: Int)? {
        guard let metadata, let data = metadata.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let width = object["width"] as? Int,
              let height = object["height"] as? Int
        else { return nil }
        return (width, height)
    }

    private func caption(for size: (width: Int, height: Int)) -> String {
        var text = "\(size.width) × \(size.height)"
        if content.hasPrefix("/") || content.hasPrefix("~") {
            text += " " + L10n.t("preview.fileReference")
        }
        return text
    }
}

extension Color {
    /// Creates a colour from a hex string.
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
            self = .clear
            return
        }
        self = Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// The hex representation of the colour.
    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(white: 0, alpha: 1)
        let red = Int(round(nsColor.redComponent * 255))
        let green = Int(round(nsColor.greenComponent * 255))
        let blue = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
