import Foundation

/// A parsed colour value.
public struct ParsedColor: Equatable, Sendable {
    /// The six digit hex representation (lower case for rgb/hsl inputs).
    public var hex: String
    /// The red channel.
    public var red: Int
    /// The green channel.
    public var green: Int
    /// The blue channel.
    public var blue: Int
    /// The hue in degrees.
    public var hue: Int
    /// The saturation in percent.
    public var saturation: Int
    /// The lightness in percent.
    public var lightness: Int

    public init(
        hex: String,
        red: Int,
        green: Int,
        blue: Int,
        hue: Int,
        saturation: Int,
        lightness: Int
    ) {
        self.hex = hex
        self.red = red
        self.green = green
        self.blue = blue
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
    }

    /// The value shown on the `HEX` row.
    public var hexDisplay: String { hex }

    /// The value shown on the `RGB` row.
    public var rgbDisplay: String { "rgb(\(red), \(green), \(blue))" }

    /// The value shown on the `HSL` row.
    public var hslDisplay: String { "hsl(\(hue), \(saturation)%, \(lightness)%)" }
}

/// Parses the colour notations Stash recognises.
///
/// Supports `#RGB`, `#RRGGBB` and `#RRGGBBAA` hex values as well as `rgb()`,
/// `rgba()`, `hsl()` and `hsla()` functions. Named colours and the four digit
/// `#RGBA` form are not supported.
public enum ColorParser {
    private static let hexRegex = try! NSRegularExpression(pattern: "^#([0-9a-fA-F]{3,8})$")
    private static let rgbRegex = try! NSRegularExpression(
        pattern: "^rgba?\\(\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)"
    )
    private static let hslRegex = try! NSRegularExpression(
        pattern: "^hsla?\\(\\s*(\\d+)\\s*,\\s*([\\d.]+)%\\s*,\\s*([\\d.]+)%"
    )

    /// Parses a colour value, returning `nil` when it is not understood.
    public static func parse(_ input: String) -> ParsedColor? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if let color = parseHex(value) { return color }
        if let color = parseRGB(value) { return color }
        if let color = parseHSL(value) { return color }
        return nil
    }

    private static func parseHex(_ value: String) -> ParsedColor? {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = hexRegex.firstMatch(in: value, options: [], range: range),
              let digitsRange = Range(match.range(at: 1), in: value)
        else { return nil }

        var digits = String(value[digitsRange])
        if digits.count == 3 {
            // `#abc` → `aabbcc`
            digits = digits.map { "\($0)\($0)" }.joined()
        }
        // Four, five and seven digit forms are not supported; eight digit values
        // keep their alpha byte in the original text but drop it for display.
        guard digits.count == 6 || digits.count == 8 else { return nil }

        let hex = "#" + String(digits.prefix(6))
        let red = Int(digits.prefix(2), radix: 16) ?? 0
        let green = Int(digits.dropFirst(2).prefix(2), radix: 16) ?? 0
        let blue = Int(digits.dropFirst(4).prefix(2), radix: 16) ?? 0
        let hsl = rgbToHSL(red: red, green: green, blue: blue)
        return ParsedColor(
            hex: hex,
            red: red,
            green: green,
            blue: blue,
            hue: hsl.hue,
            saturation: hsl.saturation,
            lightness: hsl.lightness
        )
    }

    private static func parseRGB(_ value: String) -> ParsedColor? {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = rgbRegex.firstMatch(in: value, options: [], range: range),
              let redRange = Range(match.range(at: 1), in: value),
              let greenRange = Range(match.range(at: 2), in: value),
              let blueRange = Range(match.range(at: 3), in: value)
        else { return nil }

        let red = Int(value[redRange]) ?? 0
        let green = Int(value[greenRange]) ?? 0
        let blue = Int(value[blueRange]) ?? 0
        let hex = rgbToHex(red: red, green: green, blue: blue)
        let hsl = rgbToHSL(red: red, green: green, blue: blue)
        return ParsedColor(
            hex: hex,
            red: red,
            green: green,
            blue: blue,
            hue: hsl.hue,
            saturation: hsl.saturation,
            lightness: hsl.lightness
        )
    }

    private static func parseHSL(_ value: String) -> ParsedColor? {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = hslRegex.firstMatch(in: value, options: [], range: range),
              let hueRange = Range(match.range(at: 1), in: value),
              let saturationRange = Range(match.range(at: 2), in: value),
              let lightnessRange = Range(match.range(at: 3), in: value)
        else { return nil }

        let hue = Int(value[hueRange]) ?? 0
        let saturation = Int(Double(value[saturationRange]) ?? 0)
        let lightness = Int(Double(value[lightnessRange]) ?? 0)
        let rgb = hslToRGB(hue: hue, saturation: saturation, lightness: lightness)
        return ParsedColor(
            hex: rgbToHex(red: rgb.red, green: rgb.green, blue: rgb.blue),
            red: rgb.red,
            green: rgb.green,
            blue: rgb.blue,
            hue: hue,
            saturation: saturation,
            lightness: lightness
        )
    }

    // MARK: - Conversions

    /// `#rrggbb`, lower case. Values above 255 are not clamped.
    public static func rgbToHex(red: Int, green: Int, blue: Int) -> String {
        "#" + [red, green, blue].map { String(format: "%02x", $0) }.joined()
    }

    /// Converts RGB channels into HSL.
    public static func rgbToHSL(red: Int, green: Int, blue: Int) -> (hue: Int, saturation: Int, lightness: Int) {
        let r = Double(red) / 255
        let g = Double(green) / 255
        let b = Double(blue) / 255
        let maxValue = max(r, g, b)
        let minValue = min(r, g, b)
        var hue: Double = 0
        var saturation: Double = 0
        let lightness = (maxValue + minValue) / 2

        if maxValue != minValue {
            let delta = maxValue - minValue
            saturation = lightness > 0.5 ? delta / (2 - maxValue - minValue) : delta / (maxValue + minValue)
            if maxValue == r {
                hue = ((g - b) / delta + (g < b ? 6 : 0)) / 6
            } else if maxValue == g {
                hue = ((b - r) / delta + 2) / 6
            } else {
                hue = ((r - g) / delta + 4) / 6
            }
        }

        return (
            Int((hue * 360).rounded()),
            Int((saturation * 100).rounded()),
            Int((lightness * 100).rounded())
        )
    }

    /// Converts HSL into RGB channels.
    public static func hslToRGB(hue: Int, saturation: Int, lightness: Int) -> (red: Int, green: Int, blue: Int) {
        let h = Double((hue % 360 + 360) % 360) / 360
        let s = Double(saturation) / 100
        let l = Double(lightness) / 100

        guard s != 0 else {
            let value = Int((l * 255).rounded())
            return (value, value, value)
        }

        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q

        func channel(_ offset: Double) -> Int {
            var t = offset
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            var value: Double
            if t < 1.0 / 6.0 {
                value = p + (q - p) * 6 * t
            } else if t < 1.0 / 2.0 {
                value = q
            } else if t < 2.0 / 3.0 {
                value = p + (q - p) * (2.0 / 3.0 - t) * 6
            } else {
                value = p
            }
            return Int((value * 255).rounded())
        }

        return (channel(h + 1.0 / 3.0), channel(h), channel(h - 1.0 / 3.0))
    }
}
