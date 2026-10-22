import Foundation

/// The result of inspecting a piece of clipboard text.
public struct DetectionResult: Equatable, Sendable {
    public var type: ContentType
    public var metadata: [String: String]?

    public init(type: ContentType, metadata: [String: String]? = nil) {
        self.type = type
        self.metadata = metadata
    }
}

/// Classifies clipboard text into one of Stash's content categories.
///
/// The rules and their order are identical to the previous implementation so
/// that the type filters keep matching the same items.
public enum ContentDetector {
    private static let urlRegex = try? NSRegularExpression(
        pattern: "^https?://[^\\s]+$",
        options: [.caseInsensitive]
    )
    private static let colorHexRegex = try? NSRegularExpression(
        pattern: "^#([0-9a-fA-F]{3,8})$"
    )
    private static let colorRGBRegex = try? NSRegularExpression(
        pattern: "^rgba?\\(\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*\\d+\\s*(,\\s*[\\d.]+\\s*)?\\)$"
    )
    private static let colorHSLRegex = try? NSRegularExpression(
        pattern: "^hsla?\\(\\s*\\d+\\s*,\\s*[\\d.]+%\\s*,\\s*[\\d.]+%\\s*(,\\s*[\\d.]+\\s*)?\\)$"
    )
    private static let base64Regex = try? NSRegularExpression(
        pattern: "^[A-Za-z0-9+/=]{20,}$"
    )
    private static let filePathRegex = try? NSRegularExpression(
        pattern: "^(/|~/|\\./)"
    )

    /// The indicators of the JavaScript implementation. Only the brace
    /// indicator is anchored per line, and `.` never crosses a line break.
    private static let codeIndicators: [NSRegularExpression] = [
        "\\bfunction\\b",
        "\\bconst\\b",
        "\\blet\\b",
        "\\bvar\\b",
        "\\bimport\\b.*\\bfrom\\b",
        "\\bexport\\b",
        "\\bclass\\b.*\\{",
        "\\bif\\s*\\(",
        "\\breturn\\b",
        "=>",
        "\\bdef\\b",
        "\\bfn\\b"
    ].compactMap { try? NSRegularExpression(pattern: $0) } + [
        try! NSRegularExpression(pattern: "^\\s*[{}]\\s*$", options: [.anchorsMatchLines])
    ]

    private static let languagePatterns: [(String, NSRegularExpression)] = [
        ("typescript", try! NSRegularExpression(
            pattern: "\\b(interface|type|enum|namespace|as\\s+\\w+|:\\s*(string|number|boolean|any))\\b")),
        ("javascript", try! NSRegularExpression(
            pattern: "\\b(function|const|let|var|=>|require\\(|module\\.exports)\\b")),
        ("python", try! NSRegularExpression(
            pattern: "\\b(def|class|import|from|print\\(|self\\.|if __name__)\\b")),
        ("rust", try! NSRegularExpression(
            pattern: "\\b(fn|let\\s+mut|impl|struct|enum|pub\\s+fn|use\\s+\\w+::)\\b")),
        ("go", try! NSRegularExpression(
            pattern: "\\b(func|package|import|fmt\\.|go\\s+func)\\b")),
        ("java", try! NSRegularExpression(
            pattern: "\\b(public\\s+class|private|protected|static\\s+void|System\\.out)\\b")),
        ("html", try! NSRegularExpression(
            pattern: "<\\/?[a-z][\\s\\S]*>", options: [.caseInsensitive])),
        ("css", try! NSRegularExpression(
            pattern: "[{]\\s*[\\w-]+\\s*:\\s*[^;]+;\\s*[}]")),
        ("sql", try! NSRegularExpression(
            pattern: "\\b(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|FROM|WHERE)\\b",
            options: [.caseInsensitive])),
        ("shell", try! NSRegularExpression(
            pattern: "^(#!/|apt|brew|npm|yarn|pip|curl|wget|chmod|mkdir|cd\\s)", options: [.anchorsMatchLines]))
    ]

    /// Classifies the given text.
    public static func detect(_ text: String) -> DetectionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // URL
        if matches(urlRegex, trimmed) {
            return DetectionResult(type: .url)
        }

        // Color
        if matches(colorHexRegex, trimmed)
            || matches(colorRGBRegex, trimmed)
            || matches(colorHSLRegex, trimmed) {
            return DetectionResult(type: .color, metadata: ["value": trimmed])
        }

        // JSON
        if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) && trimmed.count > 2 {
            if let data = trimmed.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
                return DetectionResult(type: .json)
            }
        }

        // Base64
        if matches(base64Regex, trimmed) && trimmed.count > 30 {
            if let decoded = Data(base64Encoded: trimmed), !decoded.isEmpty,
               decoded.base64EncodedString() == trimmed {
                return DetectionResult(type: .base64)
            }
        }

        // File path
        if matches(filePathRegex, trimmed) && !trimmed.contains("\n") {
            return DetectionResult(type: .filePath)
        }

        // Code detection
        let score = codeIndicators.reduce(0) { total, regex in
            total + (matches(regex, trimmed) ? 1 : 0)
        }
        if score >= 2 || (trimmed.contains(";") && trimmed.contains("{") && trimmed.contains("}")) {
            return DetectionResult(type: .code, metadata: ["language": detectLanguage(trimmed)])
        }

        return DetectionResult(type: .text)
    }

    /// Guesses the programming language of a code snippet.
    public static func detectLanguage(_ text: String) -> String {
        for (language, regex) in languagePatterns where matches(regex, text) {
            return language
        }
        return "plaintext"
    }

    private static func matches(_ regex: NSRegularExpression?, _ text: String) -> Bool {
        guard let regex else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
