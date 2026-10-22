import Foundation

/// A keyboard event reduced to the fields the shortcut matcher needs.
public struct KeyEventInfo: Equatable, Sendable {
    public var key: String
    public var code: String
    public var metaKey: Bool
    public var ctrlKey: Bool
    public var shiftKey: Bool
    public var altKey: Bool

    public init(
        key: String,
        code: String = "",
        metaKey: Bool = false,
        ctrlKey: Bool = false,
        shiftKey: Bool = false,
        altKey: Bool = false
    ) {
        self.key = key
        self.code = code
        self.metaKey = metaKey
        self.ctrlKey = ctrlKey
        self.shiftKey = shiftKey
        self.altKey = altKey
    }
}

/// Parsing, matching and formatting of keyboard shortcuts.
///
/// Shortcut strings use the Electron accelerator syntax, e.g.
/// `Shift+CommandOrControl+V`, `CommandOrControl+;`, `Alt`.
public enum Shortcut {
    /// Matches a key event against a shortcut definition.
    public static func matches(_ event: KeyEventInfo, _ shortcut: String) -> Bool {
        let parsed = parse(shortcut)
        guard !parsed.key.isEmpty else { return false }
        if parsed.isModifierOnly {
            let expected = parsed.usesAlt ? "Alt" : parsed.usesShift ? "Shift" : parsed.usesControl ? "Control" : "Meta"
            return event.key == expected && (!event.metaKey || parsed.usesCommand)
                && (!event.ctrlKey || parsed.usesControl) && (!event.altKey || parsed.usesAlt)
                && (!event.shiftKey || parsed.usesShift)
        }
        guard event.metaKey == parsed.usesCommand, event.ctrlKey == parsed.usesControl,
              event.shiftKey == parsed.usesShift, event.altKey == parsed.usesAlt else { return false }
        return physicalKey(event).lowercased() == parsed.key.lowercased()
    }

    /// Converts a key event into a shortcut definition for the recorder.
    /// Returns `nil` when the event does not describe a usable shortcut.
    public static func definition(from event: KeyEventInfo) -> String? {
        var parts: [String] = []
        let key = event.key
        guard !key.isEmpty else { return nil }

        let isModifier = ["Meta", "Control", "Shift", "Alt"].contains(key)

        if event.metaKey { parts.append("CommandOrControl") }
        if event.ctrlKey { parts.append("Control") }
        if event.shiftKey { parts.append("Shift") }
        if event.altKey { parts.append("Alt") }

        // A lone modifier is allowed (e.g. just "Alt").
        if isModifier && parts.count == 1 {
            return parts[0]
        }
        if isModifier { return nil }

        parts.append(mappedKey(event))
        return parts.joined(separator: "+")
    }

    /// Formats a shortcut for display, e.g. `CommandOrControl+F` → `⌘ F`.
    public static func display(_ shortcut: String) -> String {
        shortcut
            .replacingOccurrences(of: "CommandOrControl", with: "⌘")
            .replacingOccurrences(of: "Shift", with: "⇧")
            .replacingOccurrences(of: "Alt", with: "⌥")
            .replacingOccurrences(of: "Space", with: "␣")
            .replacingOccurrences(of: "Control", with: "⌃")
            .replacingOccurrences(of: "+", with: " ")
    }

    /// The physical key identity of an event, independent of the layout.
    public static func physicalKey(_ event: KeyEventInfo) -> String {
        let code = event.code

        if code.hasPrefix("Key") {
            return String(code.dropFirst(3)).uppercased()
        }
        if code.hasPrefix("Digit") {
            return String(code.dropFirst(5))
        }

        let codeMap: [String: String] = [
            "Space": "Space",
            "Comma": ",",
            "Period": ".",
            "Semicolon": ";",
            "Quote": "'",
            "Slash": "/",
            "Minus": "-",
            "Equal": "=",
            "Backquote": "`",
            "Backslash": "\\",
            "BracketLeft": "[",
            "BracketRight": "]"
        ]
        if let mapped = codeMap[code] { return mapped }
        return event.key.uppercased()
    }

    private static func mappedKey(_ event: KeyEventInfo) -> String {
        let keyMap: [String: String] = [
            " ": "Space",
            ",": ",",
            ";": ";",
            "'": "'",
            "/": "/",
            ".": ".",
            "-": "-",
            "=": "="
        ]
        if let mapped = keyMap[event.key] { return mapped }
        return physicalKey(event)
    }

    // MARK: - Parsing a shortcut into its components

    /// The parsed representation of a shortcut definition.
    public struct Parsed: Equatable, Sendable {
        public var usesCommand: Bool
        public var usesShift: Bool
        public var usesAlt: Bool
        public var usesControl: Bool
        public var key: String
        public var isModifierOnly: Bool
    }

    /// Splits a shortcut definition into its modifiers and key.
    public static func parse(_ shortcut: String) -> Parsed {
        let parts = shortcut.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard let last = parts.last, !last.isEmpty else {
            return Parsed(usesCommand: false, usesShift: false, usesAlt: false,
                          usesControl: false, key: "", isModifierOnly: false)
        }
        let key = last
        let modifiers = parts.dropLast().map { $0.lowercased() }

        if parts.count == 1 {
            switch key.lowercased() {
            case "alt", "option":
                return Parsed(usesCommand: false, usesShift: false, usesAlt: true,
                              usesControl: false, key: "Alt", isModifierOnly: true)
            case "shift":
                return Parsed(usesCommand: false, usesShift: true, usesAlt: false,
                              usesControl: false, key: "Shift", isModifierOnly: true)
            case "control", "ctrl":
                return Parsed(usesCommand: false, usesShift: false, usesAlt: false,
                              usesControl: true, key: "Control", isModifierOnly: true)
            case "commandorcontrol", "cmd", "command", "meta":
                return Parsed(usesCommand: true, usesShift: false, usesAlt: false,
                              usesControl: false, key: "CommandOrControl", isModifierOnly: true)
            default:
                return Parsed(usesCommand: false, usesShift: false, usesAlt: false,
                              usesControl: false, key: key, isModifierOnly: false)
            }
        }

        return Parsed(
            usesCommand: modifiers.contains("commandorcontrol") || modifiers.contains("cmd") || modifiers.contains("command") || modifiers.contains("meta"),
            usesShift: modifiers.contains("shift"),
            usesAlt: modifiers.contains("alt") || modifiers.contains("option"),
            usesControl: modifiers.contains("control") || modifiers.contains("ctrl"),
            key: key,
            isModifierOnly: false
        )
    }
}
