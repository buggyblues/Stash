import AppKit
import Carbon.HIToolbox

/// One physical key map shared by Carbon registration, panel navigation and recording.
public enum NativeKeyboard {
    public static let keys: [UInt16: (key: String, code: String)] = [
        0: ("A", "KeyA"), 1: ("S", "KeyS"), 2: ("D", "KeyD"), 3: ("F", "KeyF"),
        4: ("H", "KeyH"), 5: ("G", "KeyG"), 6: ("Z", "KeyZ"), 7: ("X", "KeyX"),
        8: ("C", "KeyC"), 9: ("V", "KeyV"), 11: ("B", "KeyB"), 12: ("Q", "KeyQ"),
        13: ("W", "KeyW"), 14: ("E", "KeyE"), 15: ("R", "KeyR"), 16: ("Y", "KeyY"),
        17: ("T", "KeyT"), 18: ("1", "Digit1"), 19: ("2", "Digit2"), 20: ("3", "Digit3"),
        21: ("4", "Digit4"), 22: ("6", "Digit6"), 23: ("5", "Digit5"), 24: ("=", "Equal"),
        25: ("9", "Digit9"), 26: ("7", "Digit7"), 27: ("-", "Minus"), 28: ("8", "Digit8"),
        29: ("0", "Digit0"), 30: ("]", "BracketRight"), 31: ("O", "KeyO"), 32: ("U", "KeyU"),
        33: ("[", "BracketLeft"), 34: ("I", "KeyI"), 35: ("P", "KeyP"), 36: ("Enter", "Enter"),
        37: ("L", "KeyL"), 38: ("J", "KeyJ"), 39: ("'", "Quote"), 40: ("K", "KeyK"),
        41: (";", "Semicolon"), 42: ("\\", "Backslash"), 43: (",", "Comma"), 44: ("/", "Slash"),
        45: ("N", "KeyN"), 46: ("M", "KeyM"), 47: (".", "Period"), 48: ("Tab", "Tab"),
        49: (" ", "Space"), 50: ("`", "Backquote"), 51: ("Backspace", "Backspace"),
        53: ("Escape", "Escape"), 76: ("Enter", "NumpadEnter"), 117: ("Delete", "Delete"),
        115: ("Home", "Home"), 119: ("End", "End"),
        116: ("PageUp", "PageUp"), 121: ("PageDown", "PageDown"),
        122: ("F1", "F1"), 120: ("F2", "F2"), 99: ("F3", "F3"), 118: ("F4", "F4"),
        96: ("F5", "F5"), 97: ("F6", "F6"), 98: ("F7", "F7"), 100: ("F8", "F8"),
        101: ("F9", "F9"), 109: ("F10", "F10"), 103: ("F11", "F11"), 111: ("F12", "F12"),
        105: ("F13", "F13"), 107: ("F14", "F14"), 113: ("F15", "F15"), 106: ("F16", "F16"),
        64: ("F17", "F17"), 79: ("F18", "F18"), 80: ("F19", "F19"), 90: ("F20", "F20"),
        123: ("ArrowLeft", "ArrowLeft"), 124: ("ArrowRight", "ArrowRight"),
        125: ("ArrowDown", "ArrowDown"), 126: ("ArrowUp", "ArrowUp")
    ]

    public static func info(for event: NSEvent) -> KeyEventInfo {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var key = event.charactersIgnoringModifiers ?? ""
        if event.type == .flagsChanged {
            switch flags.intersection([.command, .control, .shift, .option]) {
            case .command: key = "Meta"
            case .control: key = "Control"
            case .shift: key = "Shift"
            case .option: key = "Alt"
            default: key = ""
            }
        } else if let physical = keys[event.keyCode], !physical.code.hasPrefix("Key"),
                  !physical.code.hasPrefix("Digit") {
            key = physical.key
        }
        return KeyEventInfo(key: key, code: keys[event.keyCode]?.code ?? "",
                            metaKey: flags.contains(.command), ctrlKey: flags.contains(.control),
                            shiftKey: flags.contains(.shift), altKey: flags.contains(.option))
    }
}

public struct HotKeyDescriptor {
    public let keyCode: UInt32
    public let carbonModifiers: UInt32

    public init?(accelerator: String) {
        let parts = accelerator.split(separator: "+").map { $0.lowercased() }
        let modifiers = Set(["commandorcontrol", "cmd", "command", "meta", "shift", "alt", "option", "ctrl", "control"])
        guard parts.dropLast().allSatisfy(modifiers.contains) else { return nil }
        let parsed = Shortcut.parse(accelerator)
        guard !parsed.isModifierOnly else { return nil }
        let aliases = ["space": " ", "return": "enter", "esc": "escape", "left": "arrowleft",
                       "right": "arrowright", "up": "arrowup", "down": "arrowdown"]
        let key = aliases[parsed.key.lowercased()] ?? parsed.key.lowercased()
        guard let entry = NativeKeyboard.keys.sorted(by: { $0.key < $1.key }).first(where: {
            $0.value.key.lowercased() == key
        }) else { return nil }
        keyCode = UInt32(entry.key)
        carbonModifiers = (parsed.usesCommand ? UInt32(cmdKey) : 0)
            | (parsed.usesControl ? UInt32(controlKey) : 0)
            | (parsed.usesShift ? UInt32(shiftKey) : 0)
            | (parsed.usesAlt ? UInt32(optionKey) : 0)
    }
}
