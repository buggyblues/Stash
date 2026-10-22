import Foundation

/// A JSON value that keeps the order of the object keys.
///
/// `JSONSerialization` returns unordered dictionaries and prints a space
/// before the colon, so the pretty printed output of the previous build
/// (`JSON.stringify(value, null, 2)`) is reproduced with this type instead.
public enum JSONValue: Equatable {
    /// A key/value pair of a JSON object.
    public struct Member: Equatable {
        public var key: String
        public var value: JSONValue

        public init(key: String, value: JSONValue) {
            self.key = key
            self.value = value
        }
    }

    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([Member])

    /// Parses a JSON document.
    public static func parse(_ text: String) -> JSONValue? {
        var parser = JSONParser(Array(text.utf8))
        guard let value = parser.parseValue() else { return nil }
        parser.skipWhitespace()
        guard parser.isAtEnd else { return nil }
        return value
    }

    /// Serialises the value with the given indentation, like
    /// `JSON.stringify(value, null, indent)`.
    public func serialized(indent: Int = 2) -> String {
        var output = ""
        write(into: &output, indent: indent, level: 0)
        return output
    }

    private func write(into output: inout String, indent: Int, level: Int) {
        let pad = String(repeating: " ", count: indent * level)
        let innerPad = String(repeating: " ", count: indent * (level + 1))

        switch self {
        case .null:
            output += "null"
        case let .bool(value):
            output += value ? "true" : "false"
        case let .number(value):
            output += Self.formatNumber(value)
        case let .string(value):
            output += Self.quote(value)
        case let .array(items):
            if items.isEmpty {
                output += "[]"
                return
            }
            output += "[\n"
            for (index, item) in items.enumerated() {
                output += innerPad
                item.write(into: &output, indent: indent, level: level + 1)
                output += index == items.count - 1 ? "\n" : ",\n"
            }
            output += pad + "]"
        case let .object(entries):
            if entries.isEmpty {
                output += "{}"
                return
            }
            output += "{\n"
            for (index, entry) in entries.enumerated() {
                output += innerPad + Self.quote(entry.key) + ": "
                entry.value.write(into: &output, indent: indent, level: level + 1)
                output += index == entries.count - 1 ? "\n" : ",\n"
            }
            output += pad + "}"
        }
    }

    /// Formats a number the way JavaScript does.
    static func formatNumber(_ value: Double) -> String {
        if value.isNaN || value.isInfinite { return "null" }
        if value == value.rounded(), abs(value) < 1e21 {
            return String(Int64(value))
        }
        return String(value)
    }

    /// Quotes and escapes a string like JavaScript does.
    static func quote(_ value: String) -> String {
        var result = "\""
        for character in value {
            switch character {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case "\u{08}": result += "\\b"
            case "\u{0C}": result += "\\f"
            default:
                if character.unicodeScalars.first?.value ?? 0 < 0x20 {
                    result += String(format: "\\u%04x", character.unicodeScalars.first?.value ?? 0)
                } else {
                    result.append(character)
                }
            }
        }
        return result + "\""
    }
}

/// A minimal JSON parser that keeps the order of the object keys.
struct JSONParser {
    private let bytes: [UInt8]
    private var index: Int = 0

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    var isAtEnd: Bool { index >= bytes.count }

    mutating func skipWhitespace() {
        while index < bytes.count {
            switch bytes[index] {
            case 0x20, 0x09, 0x0A, 0x0D: index += 1
            default: return
            }
        }
    }

    mutating func parseValue() -> JSONValue? {
        skipWhitespace()
        guard index < bytes.count else { return nil }
        switch bytes[index] {
        case UInt8(ascii: "{"): return parseObject()
        case UInt8(ascii: "["): return parseArray()
        case UInt8(ascii: "\""): return parseString().map { .string($0) }
        case UInt8(ascii: "t"):
            guard matches("true") else { return nil }
            return .bool(true)
        case UInt8(ascii: "f"):
            guard matches("false") else { return nil }
            return .bool(false)
        case UInt8(ascii: "n"):
            guard matches("null") else { return nil }
            return .null
        default:
            return parseNumber()
        }
    }

    private mutating func matches(_ literal: String) -> Bool {
        let expected = Array(literal.utf8)
        guard index + expected.count <= bytes.count else { return false }
        for (offset, byte) in expected.enumerated() where bytes[index + offset] != byte {
            return false
        }
        index += expected.count
        return true
    }

    private mutating func parseObject() -> JSONValue? {
        index += 1 // '{'
        var entries: [JSONValue.Member] = []
        skipWhitespace()
        if index < bytes.count, bytes[index] == UInt8(ascii: "}") {
            index += 1
            return .object(entries)
        }
        while true {
            skipWhitespace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else { return nil }
            guard let key = parseString() else { return nil }
            skipWhitespace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: ":") else { return nil }
            index += 1
            guard let value = parseValue() else { return nil }
            entries.append(JSONValue.Member(key: key, value: value))
            skipWhitespace()
            guard index < bytes.count else { return nil }
            if bytes[index] == UInt8(ascii: ",") {
                index += 1
                continue
            }
            if bytes[index] == UInt8(ascii: "}") {
                index += 1
                return .object(entries)
            }
            return nil
        }
    }

    private mutating func parseArray() -> JSONValue? {
        index += 1 // '['
        var items: [JSONValue] = []
        skipWhitespace()
        if index < bytes.count, bytes[index] == UInt8(ascii: "]") {
            index += 1
            return .array(items)
        }
        while true {
            guard let value = parseValue() else { return nil }
            items.append(value)
            skipWhitespace()
            guard index < bytes.count else { return nil }
            if bytes[index] == UInt8(ascii: ",") {
                index += 1
                continue
            }
            if bytes[index] == UInt8(ascii: "]") {
                index += 1
                return .array(items)
            }
            return nil
        }
    }

    private mutating func parseString() -> String? {
        guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else { return nil }
        index += 1
        var result = ""
        var pendingHighSurrogate: UInt32?

        while index < bytes.count {
            let byte = bytes[index]
            if byte == UInt8(ascii: "\"") {
                index += 1
                if pendingHighSurrogate != nil { result.append("\u{FFFD}") }
                return result
            }
            if byte == UInt8(ascii: "\\") {
                index += 1
                guard index < bytes.count else { return nil }
                let escape = bytes[index]
                index += 1
                switch escape {
                case UInt8(ascii: "\""): result.append("\"")
                case UInt8(ascii: "\\"): result.append("\\")
                case UInt8(ascii: "/"): result.append("/")
                case UInt8(ascii: "b"): result.append("\u{08}")
                case UInt8(ascii: "f"): result.append("\u{0C}")
                case UInt8(ascii: "n"): result.append("\n")
                case UInt8(ascii: "r"): result.append("\r")
                case UInt8(ascii: "t"): result.append("\t")
                case UInt8(ascii: "u"):
                    guard index + 4 <= bytes.count else { return nil }
                    let hex = String(decoding: bytes[index..<(index + 4)], as: UTF8.self)
                    guard let scalarValue = UInt32(hex, radix: 16) else { return nil }
                    index += 4
                    if scalarValue >= 0xD800, scalarValue <= 0xDBFF {
                        pendingHighSurrogate = scalarValue
                        continue
                    }
                    if let high = pendingHighSurrogate {
                        pendingHighSurrogate = nil
                        if scalarValue >= 0xDC00, scalarValue <= 0xDFFF {
                            let combined = 0x10000 + (high - 0xD800) * 0x400 + (scalarValue - 0xDC00)
                            if let scalar = Unicode.Scalar(combined) {
                                result.unicodeScalars.append(scalar)
                                continue
                            }
                        }
                        result.append("\u{FFFD}")
                    }
                    if let scalar = Unicode.Scalar(scalarValue) {
                        result.unicodeScalars.append(scalar)
                    }
                default:
                    return nil
                }
                continue
            }
            if pendingHighSurrogate != nil {
                result.append("\u{FFFD}")
                pendingHighSurrogate = nil
            }
            // Collect the raw UTF-8 bytes of the character.
            let length = Self.utf8Length(byte)
            let start = index
            index = min(index + length, bytes.count)
            if let slice = String(bytes: bytes[start..<index], encoding: .utf8) {
                result += slice
            } else {
                result.append("\u{FFFD}")
            }
        }
        return nil
    }

    private static func utf8Length(_ byte: UInt8) -> Int {
        if byte < 0x80 { return 1 }
        if byte & 0xE0 == 0xC0 { return 2 }
        if byte & 0xF0 == 0xE0 { return 3 }
        if byte & 0xF8 == 0xF0 { return 4 }
        return 1
    }

    private mutating func parseNumber() -> JSONValue? {
        let start = index
        if index < bytes.count, bytes[index] == UInt8(ascii: "-") { index += 1 }
        while index < bytes.count {
            let byte = bytes[index]
            let isDigit = byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
            let isPart = isDigit || byte == UInt8(ascii: ".") || byte == UInt8(ascii: "e")
                || byte == UInt8(ascii: "E") || byte == UInt8(ascii: "+") || byte == UInt8(ascii: "-")
            guard isPart else { break }
            index += 1
        }
        guard index > start else { return nil }
        let text = String(decoding: bytes[start..<index], as: UTF8.self)
        guard let value = Double(text) else { return nil }
        return .number(value)
    }
}
