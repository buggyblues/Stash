import SwiftUI
import StashCore

/// Reading surfaces and semantic colors, separate from system glass materials.
public struct StashTheme: Equatable {
    public var resolved: ResolvedTheme
    public var accentHex: String

    public init(resolved: ResolvedTheme, accentHex: String) {
        self.resolved = resolved
        self.accentHex = accentHex
    }

    public var isDark: Bool { resolved == .dark }

    // MARK: - Accent

    /// The HSL components of the accent colour.
    public var accent: (hue: Double, saturation: Double, lightness: Double) {
        Self.hexToHSL(accentHex)
    }

    /// The accent colour as it is displayed in the current appearance.
    public var accentColor: Color {
        Self.color(fromHex: accentHex)
    }

    /// The foreground colour used on top of the accent colour.
    public var accentForeground: Color {
        let (_, _, l) = accent
        let lightness = isDark ? min(max(l, 50) + 8, 80) : l
        return lightness > 58 ? Color(white: 0.07) : Color(white: 1.0)
    }

    // MARK: - Liquid Glass & Surfaces

    public var background: Color {
        isDark ? Color(white: 0.115) : Color(white: 0.975)
    }

    public var headerBackground: Color {
        Color.clear
    }

    public var card: Color {
        isDark ? Color(white: 0.15) : Color.white
    }

    public var cardElevated: Color {
        isDark ? Color(white: 0.19) : Color.white
    }

    public var foreground: Color {
        isDark ? Color(white: 0.96) : Color(white: 0.10)
    }

    public var muted: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }

    public var mutedForeground: Color {
        isDark ? Color(white: 0.69) : Color(white: 0.40)
    }

    public var border: Color {
        if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
            return isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.45)
        }
        return isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    public var destructive: Color {
        isDark ? Color(red: 0.96, green: 0.38, blue: 0.38) : Color(red: 0.88, green: 0.22, blue: 0.22)
    }

    public var ring: Color { accentColor }

    // MARK: - Apple HIG Specular Highlights & Shadows

    /// Apple signature specular top-edge light reflection.
    public var specularHighlight: LinearGradient {
        specularHighlight(opacity: 1.0)
    }

    /// Subtle specular top-edge highlight for cards and inner elements.
    public var subtleSpecularHighlight: LinearGradient {
        specularHighlight(opacity: 0.4)
    }

    public func specularHighlight(opacity: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity((isDark ? 0.22 : 0.95) * opacity),
                Color.white.opacity((isDark ? 0.05 : 0.25) * opacity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public var windowShadowColor: Color {
        Color.black.opacity(isDark ? 0.65 : 0.16)
    }

    public var windowShadowRadius: CGFloat {
        isDark ? 28.0 : 20.0
    }

    // MARK: - Syntax colours

    /// The colour of a highlighted token.
    public func color(for kind: TokenKind) -> Color {
        switch kind {
        case .plain:
            return foreground
        case .keyword:
            return isDark ? Color(red: 0.80, green: 0.46, blue: 0.46) : Color(red: 0.67, green: 0.35, blue: 0.35)
        case .type:
            return isDark ? Color(red: 0.79, green: 0.64, blue: 0.43) : Color(red: 0.76, green: 0.52, blue: 0.01)
        case .string:
            return isDark ? Color(red: 0.31, green: 0.63, blue: 0.31) : Color(red: 0.31, green: 0.63, blue: 0.31)
        case .number:
            return isDark ? Color(red: 0.71, green: 0.52, blue: 0.0) : Color(red: 0.60, green: 0.40, blue: 0.0)
        case .comment:
            return isDark ? Color(red: 0.46, green: 0.52, blue: 0.46) : Color(red: 0.63, green: 0.68, blue: 0.63)
        case .function:
            return isDark ? Color(red: 0.30, green: 0.58, blue: 0.46) : Color(red: 0.25, green: 0.47, blue: 0.95)
        case .punctuation:
            return isDark ? Color(white: 0.40) : Color(white: 0.22)
        case .tagName:
            return isDark ? Color(red: 0.88, green: 0.42, blue: 0.46) : Color(red: 0.67, green: 0.35, blue: 0.35)
        case .attribute:
            return isDark ? Color(red: 0.82, green: 0.60, blue: 0.40) : Color(red: 0.82, green: 0.52, blue: 0.26)
        case .property:
            return isDark ? Color(red: 0.55, green: 0.70, blue: 0.95) : Color(red: 0.20, green: 0.40, blue: 0.75)
        }
    }

    // MARK: - Helpers

    /// Converts a hex colour into HSL components.
    public static func hexToHSL(_ hex: String) -> (hue: Double, saturation: Double, lightness: Double) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
            return (21, 100, 64)
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        let maximum = max(r, g, b)
        let minimum = min(r, g, b)
        var hue: Double = 0
        var saturation: Double = 0
        let lightness = (maximum + minimum) / 2

        if maximum != minimum {
            let delta = maximum - minimum
            saturation = lightness > 0.5 ? delta / (2 - maximum - minimum) : delta / (maximum + minimum)
            if maximum == r {
                hue = ((g - b) / delta + (g < b ? 6 : 0)) / 6
            } else if maximum == g {
                hue = ((b - r) / delta + 2) / 6
            } else {
                hue = ((r - g) / delta + 4) / 6
            }
        }
        return (hue * 360, saturation * 100, lightness * 100)
    }

    /// Parses a hex colour into an `NSColor` compatible `Color`.
    public static func color(fromHex hex: String) -> Color {
        let sanitized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
            return Color(red: 1, green: 0.5, blue: 0.26)
        }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// A colour that adapts to the current appearance.
public struct AdaptiveColor: View {
    private let light: Color
    private let dark: Color
    private let theme: StashTheme

    public init(light: Color, dark: Color, theme: StashTheme) {
        self.light = light
        self.dark = dark
        self.theme = theme
    }

    public var body: some View {
        theme.isDark ? dark : light
    }
}
