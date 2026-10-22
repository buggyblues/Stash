import Foundation

/// The kind of a highlighted token.
public enum TokenKind: Equatable, Sendable {
    case plain
    case keyword
    case type
    case string
    case number
    case comment
    case function
    case punctuation
    case tagName
    case attribute
    case property
}

/// A single highlighted fragment of a line.
public struct SyntaxToken: Equatable, Sendable {
    public var kind: TokenKind
    public var text: String

    public init(kind: TokenKind, text: String) {
        self.kind = kind
        self.text = text
    }
}

/// The languages the highlighter understands.
public enum SyntaxLanguage: String, CaseIterable, Sendable {
    case typescript
    case javascript
    case python
    case rust
    case go
    case java
    case html
    case css
    case sql
    case shell
    case plaintext

    /// Maps the language identifier produced by `ContentDetector` onto a
    /// supported language.
    public init(detected: String) {
        self = SyntaxLanguage(rawValue: detected) ?? .plaintext
    }
}

/// A lightweight syntax highlighter.
///
/// It tokenises the languages Stash can detect into keywords, strings,
/// numbers, comments, types and function calls so the preview panel can
/// colour code without shipping a full grammar runtime.
public enum SyntaxHighlighter {
    /// A highlighted line.
    public struct Line: Equatable, Sendable {
        public var tokens: [SyntaxToken]

        public init(tokens: [SyntaxToken]) {
            self.tokens = tokens
        }
    }

    /// Highlights a snippet, returning one entry per line.
    public static func highlight(_ code: String, language: SyntaxLanguage) -> [Line] {
        switch language {
        case .html:
            return highlightHTML(code)
        case .css:
            return highlightCSS(code)
        default:
            return highlightGeneric(code, language: language)
        }
    }

    // MARK: - Generic languages

    private static func highlightGeneric(_ code: String, language: SyntaxLanguage) -> [Line] {
        let keywords = keywords(for: language)
        let types = types(for: language)
        let lineComments = lineCommentMarkers(for: language)
        let blockComments = blockCommentMarkers(for: language)
        let stringDelimiters = stringDelimiters(for: language)

        var lines: [Line] = []
        var inBlockComment = false

        for rawLine in splitLines(code) {
            var tokens: [SyntaxToken] = []
            var index = rawLine.startIndex
            var pending = ""

            func flushPending() {
                if !pending.isEmpty {
                    tokens.append(SyntaxToken(kind: .plain, text: pending))
                    pending = ""
                }
            }

            while index < rawLine.endIndex {
                let character = rawLine[index]
                let remainder = String(rawLine[index...])

                // Block comment
                if !blockComments.isEmpty {
                    if inBlockComment {
                        if let (end, marker) = blockComments.first(where: { remainder.hasPrefix($0.end) }) {
                            pending += marker
                            flushPending()
                            inBlockComment = false
                            index = rawLine.index(index, offsetBy: marker.count)
                            continue
                        }
                        pending.append(character)
                        index = rawLine.index(after: index)
                        continue
                    }
                    if let (start, _) = blockComments.first(where: { remainder.hasPrefix($0.start) }) {
                        flushPending()
                        tokens.append(SyntaxToken(kind: .comment, text: start))
                        inBlockComment = true
                        index = rawLine.index(index, offsetBy: start.count)
                        continue
                    }
                }

                // Line comment
                if let marker = lineComments.first(where: { remainder.hasPrefix($0) }),
                   !inBlockComment {
                    flushPending()
                    tokens.append(SyntaxToken(kind: .comment, text: String(remainder)))
                    index = rawLine.endIndex
                    break
                }

                // Strings
                if stringDelimiters.contains(character), !inBlockComment {
                    let (string, consumed) = readString(from: remainder, delimiter: character)
                    flushPending()
                    tokens.append(SyntaxToken(kind: .string, text: string))
                    index = rawLine.index(index, offsetBy: consumed)
                    continue
                }

                // Numbers
                if character.isNumber, !inBlockComment {
                    var consumed = 0
                    var text = ""
                    var seenDot = false
                    for candidate in remainder {
                        if candidate.isNumber || candidate == "_" {
                            text.append(candidate)
                            consumed += 1
                        } else if candidate == "." && !seenDot && consumed + 1 < remainder.count,
                                  remainder.index(remainder.startIndex, offsetBy: consumed + 1) < remainder.endIndex,
                                  remainder[remainder.index(remainder.startIndex, offsetBy: consumed + 1)].isNumber {
                            seenDot = true
                            text.append(candidate)
                            consumed += 1
                        } else {
                            break
                        }
                    }
                    if !text.isEmpty {
                        flushPending()
                        tokens.append(SyntaxToken(kind: .number, text: text))
                        index = rawLine.index(index, offsetBy: consumed)
                        continue
                    }
                }

                // Identifiers
                if character.isLetter || character == "_" || character == "$" {
                    var text = ""
                    var cursor = index
                    while cursor < rawLine.endIndex {
                        let candidate = rawLine[cursor]
                        if candidate.isLetter || candidate.isNumber || candidate == "_" || candidate == "$" {
                            text.append(candidate)
                            cursor = rawLine.index(after: cursor)
                        } else {
                            break
                        }
                    }
                    flushPending()

                    let upper = text.uppercased()
                    let kind: TokenKind
                    if keywords.contains(upper) {
                        kind = .keyword
                    } else if types.contains(upper) {
                        kind = .type
                    } else if isFunctionCall(rawLine, after: cursor) {
                        kind = .function
                    } else if text.first == "$" || text.hasPrefix("$") {
                        kind = .type
                    } else {
                        kind = .plain
                    }
                    tokens.append(SyntaxToken(kind: kind, text: text))
                    index = cursor
                    continue
                }

                // Punctuation
                if "{}()[];,.:=+-*/%<>!&|^~?".contains(character) {
                    flushPending()
                    tokens.append(SyntaxToken(kind: .punctuation, text: String(character)))
                    index = rawLine.index(after: index)
                    continue
                }

                pending.append(character)
                index = rawLine.index(after: index)
            }

            flushPending()
            lines.append(Line(tokens: tokens))
        }

        return lines
    }

    private static func isFunctionCall(_ line: String, after index: String.Index) -> Bool {
        var cursor = index
        while cursor < line.endIndex, line[cursor] == " " { cursor = line.index(after: cursor) }
        return cursor < line.endIndex && line[cursor] == "("
    }

    private static func readString(from text: String, delimiter: Character) -> (String, Int) {
        var result = String(delimiter)
        var consumed = 1
        var escaped = false
        var iterator = text.index(after: text.startIndex)

        while iterator < text.endIndex {
            let character = text[iterator]
            result.append(character)
            consumed += 1
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == delimiter {
                break
            }
            iterator = text.index(after: iterator)
        }
        return (result, consumed)
    }

    // MARK: - HTML

    private static func highlightHTML(_ code: String) -> [Line] {
        var lines: [Line] = []
        var inComment = false

        for rawLine in splitLines(code) {
            var tokens: [SyntaxToken] = []
            var index = rawLine.startIndex
            var pending = ""

            func flushPending() {
                if !pending.isEmpty {
                    tokens.append(SyntaxToken(kind: .plain, text: pending))
                    pending = ""
                }
            }

            while index < rawLine.endIndex {
                let character = rawLine[index]
                let remainder = String(rawLine[index...])

                if inComment {
                    if let end = remainder.range(of: "-->") {
                        pending += String(remainder[remainder.startIndex..<end.upperBound])
                        flushPending()
                        tokens.append(SyntaxToken(kind: .comment, text: pending))
                        pending = ""
                        inComment = false
                        index = end.upperBound
                        continue
                    }
                    pending.append(character)
                    index = rawLine.index(after: index)
                    continue
                }

                if remainder.hasPrefix("<!--") {
                    flushPending()
                    pending = "<!--"
                    inComment = true
                    index = rawLine.index(index, offsetBy: 4)
                    continue
                }

                if character == "<" {
                    flushPending()
                    var tagText = "<"
                    var cursor = rawLine.index(after: index)
                    var isClosing = false
                    if cursor < rawLine.endIndex, rawLine[cursor] == "/" {
                        isClosing = true
                        tagText += "/"
                        cursor = rawLine.index(after: cursor)
                    }
                    var name = ""
                    while cursor < rawLine.endIndex, rawLine[cursor].isLetter || rawLine[cursor].isNumber {
                        name.append(rawLine[cursor])
                        cursor = rawLine.index(after: cursor)
                    }
                    if !name.isEmpty {
                        tagText += name
                        tokens.append(SyntaxToken(kind: .tagName, text: tagText))
                        tagText = ""
                    } else {
                        pending = "<"
                    }
                    index = cursor
                    continue
                }

                if character == ">" {
                    flushPending()
                    tokens.append(SyntaxToken(kind: .tagName, text: ">"))
                    index = rawLine.index(after: index)
                    continue
                }

                // Attribute names inside a tag.
                if character == "=", index < rawLine.endIndex {
                    let next = rawLine.index(after: index)
                    guard next < rawLine.endIndex else { break }
                    let valueStart = rawLine[next]
                    if valueStart == "\"" || valueStart == "'" {
                        flushPending()
                        var text = String(valueStart)
                        var cursor = next
                        while cursor < rawLine.endIndex {
                            let current = rawLine[cursor]
                            text.append(current)
                            cursor = rawLine.index(after: cursor)
                            if current == valueStart { break }
                        }
                        tokens.append(SyntaxToken(kind: .string, text: text))
                        index = cursor
                        continue
                    }
                }

                pending.append(character)
                index = rawLine.index(after: index)
            }

            flushPending()
            lines.append(Line(tokens: tokens))
        }
        return lines
    }

    // MARK: - CSS

    private static func highlightCSS(_ code: String) -> [Line] {
        var lines: [Line] = []
        var inBlockComment = false

        for rawLine in splitLines(code) {
            var tokens: [SyntaxToken] = []
            var index = rawLine.startIndex
            var pending = ""
            var afterColon = false

            func flushPending() {
                if !pending.isEmpty {
                    tokens.append(SyntaxToken(kind: .plain, text: pending))
                    pending = ""
                }
            }

            while index < rawLine.endIndex {
                let character = rawLine[index]
                let remainder = String(rawLine[index...])

                if inBlockComment {
                    if let end = remainder.range(of: "*/") {
                        pending += String(remainder[remainder.startIndex..<end.upperBound])
                        flushPending()
                        pending = ""
                        inBlockComment = false
                        index = end.upperBound
                        continue
                    }
                    pending.append(character)
                    index = rawLine.index(after: index)
                    continue
                }

                if remainder.hasPrefix("/*") {
                    flushPending()
                    pending = "/*"
                    inBlockComment = true
                    index = rawLine.index(index, offsetBy: 2)
                    continue
                }

                if character == "\"" || character == "'" {
                    let (text, consumed) = readString(from: remainder, delimiter: character)
                    flushPending()
                    tokens.append(SyntaxToken(kind: .string, text: text))
                    index = rawLine.index(index, offsetBy: consumed)
                    continue
                }

                if character == ":" {
                    flushPending()
                    tokens.append(SyntaxToken(kind: .punctuation, text: ":"))
                    afterColon = true
                    index = rawLine.index(after: index)
                    continue
                }

                if character == ";" || character == "{" || character == "}" {
                    flushPending()
                    tokens.append(SyntaxToken(kind: .punctuation, text: String(character)))
                    afterColon = false
                    index = rawLine.index(after: index)
                    continue
                }

                if character.isLetter || character == "_" || character == "-" || character == "#" {
                    var text = ""
                    var cursor = index
                    while cursor < rawLine.endIndex {
                        let candidate = rawLine[cursor]
                        if candidate.isLetter || candidate.isNumber || candidate == "_"
                            || candidate == "-" || candidate == "#" || candidate == "." {
                            text.append(candidate)
                            cursor = rawLine.index(after: cursor)
                        } else {
                            break
                        }
                    }
                    guard !text.isEmpty else { break }
                    flushPending()
                    let kind: TokenKind = afterColon ? .string : .property
                    tokens.append(SyntaxToken(kind: kind, text: text))
                    index = cursor
                    continue
                }

                pending.append(character)
                index = rawLine.index(after: index)
            }

            flushPending()
            lines.append(Line(tokens: tokens))
        }
        return lines
    }

    // MARK: - Helpers

    private static func splitLines(_ text: String) -> [String] {
        var lines: [String] = []
        lines.reserveCapacity(64)
        var current = ""
        for character in text {
            if character == "\n" {
                lines.append(current)
                current = ""
            } else if character != "\r" {
                current.append(character)
            }
        }
        lines.append(current)
        return lines
    }

    private static func keywords(for language: SyntaxLanguage) -> Set<String> {
        switch language {
        case .typescript:
            return [
                "CONST", "LET", "VAR", "FUNCTION", "RETURN", "IF", "ELSE", "FOR", "WHILE", "DO",
                "SWITCH", "CASE", "BREAK", "CONTINUE", "NEW", "CLASS", "EXTENDS", "IMPLEMENTS",
                "INTERFACE", "TYPE", "ENUM", "IMPORT", "EXPORT", "FROM", "DEFAULT", "TRY", "CATCH",
                "FINALLY", "THROW", "ASYNC", "AWAIT", "YIELD", "DELETE", "TYPEOF", "INSTANCEOF",
                "IN", "OF", "THIS", "SUPER", "STATIC", "PUBLIC", "PRIVATE", "PROTECTED", "READONLY",
                "ABSTRACT", "NULL", "UNDEFINED", "TRUE", "FALSE", "DECLARE", "NAMESPACE", "AS",
                "KEYOF", "INFER", "IS", "SATISFIES", "OVERRIDE"
            ]
        case .javascript:
            return [
                "CONST", "LET", "VAR", "FUNCTION", "RETURN", "IF", "ELSE", "FOR", "WHILE", "DO",
                "SWITCH", "CASE", "BREAK", "CONTINUE", "NEW", "CLASS", "EXTENDS", "IMPORT", "EXPORT",
                "FROM", "DEFAULT", "TRY", "CATCH", "FINALLY", "THROW", "ASYNC", "AWAIT", "YIELD",
                "DELETE", "TYPEOF", "INSTANCEOF", "IN", "OF", "THIS", "SUPER", "STATIC", "NULL",
                "UNDEFINED", "TRUE", "FALSE"
            ]
        case .python:
            return [
                "DEF", "CLASS", "IMPORT", "FROM", "AS", "IF", "ELIF", "ELSE", "FOR", "WHILE",
                "RETURN", "YIELD", "TRY", "EXCEPT", "FINALLY", "RAISE", "WITH", "LAMBDA", "PASS",
                "BREAK", "CONTINUE", "GLOBAL", "NONLOCAL", "ASSERT", "DEL", "IN", "IS", "NOT",
                "AND", "OR", "NONE", "TRUE", "FALSE", "SELF", "MATCH", "CASE"
            ]
        case .rust:
            return [
                "FN", "LET", "MUT", "IMPL", "STRUCT", "ENUM", "TRAIT", "PUB", "USE", "MOD",
                "MATCH", "IF", "ELSE", "FOR", "WHILE", "LOOP", "RETURN", "SELF", "SELF_", "CRATE",
                "SUPER", "WHERE", "ASYNC", "AWAIT", "MOVE", "REF", "DYN", "CONST", "STATIC",
                "TYPE", "UNSAFE", "TRUE", "FALSE", "AS", "IN", "BREAK", "CONTINUE"
            ]
        case .go:
            return [
                "FUNC", "PACKAGE", "IMPORT", "VAR", "CONST", "TYPE", "STRUCT", "INTERFACE", "MAP",
                "CHAN", "GO", "DEFER", "IF", "ELSE", "FOR", "RANGE", "RETURN", "SWITCH", "CASE",
                "DEFAULT", "BREAK", "CONTINUE", "SELECT", "NIL", "TRUE", "FALSE", "FALLTHROUGH"
            ]
        case .java:
            return [
                "PUBLIC", "PRIVATE", "PROTECTED", "STATIC", "VOID", "CLASS", "INTERFACE", "EXTENDS",
                "IMPLEMENTS", "NEW", "RETURN", "IF", "ELSE", "FOR", "WHILE", "DO", "SWITCH", "CASE",
                "BREAK", "CONTINUE", "TRY", "CATCH", "FINALLY", "THROW", "THROWS", "IMPORT", "PACKAGE",
                "FINAL", "ABSTRACT", "SYNCHRONIZED", "THIS", "SUPER", "NULL", "TRUE", "FALSE"
            ]
        case .sql:
            return [
                "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP", "FROM", "WHERE",
                "INNER", "LEFT", "RIGHT", "FULL", "OUTER", "JOIN", "ON", "GROUP", "BY", "ORDER",
                "HAVING", "LIMIT", "OFFSET", "VALUES", "SET", "INTO", "TABLE", "INDEX", "VIEW",
                "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "UNIQUE", "NOT", "NULL", "AND", "OR",
                "AS", "DISTINCT", "COUNT", "SUM", "AVG", "MIN", "MAX", "CASE", "WHEN", "THEN", "ELSE", "END"
            ]
        case .shell:
            return [
                "IF", "THEN", "ELSE", "ELIF", "FI", "FOR", "WHILE", "DO", "DONE", "CASE", "ESAC",
                "FUNCTION", "RETURN", "LOCAL", "EXPORT", "ECHO", "CD", "EXIT", "SET", "SOURCE"
            ]
        case .html, .css, .plaintext:
            return []
        }
    }

    private static func types(for language: SyntaxLanguage) -> Set<String> {
        switch language {
        case .typescript:
            return ["STRING", "NUMBER", "BOOLEAN", "ANY", "UNKNOWN", "NEVER", "VOID", "OBJECT", "ARRAY"]
        case .javascript:
            return []
        case .python:
            return ["INT", "STR", "FLOAT", "BOOL", "LIST", "DICT", "SET", "TUPLE", "BYTES", "OBJECT"]
        case .rust:
            return ["U8", "U16", "U32", "U64", "USIZE", "I8", "I16", "I32", "I64", "ISIZE", "F32", "F64", "BOOL", "CHAR", "STR"]
        case .go:
            return ["INT", "INT8", "INT16", "INT32", "INT64", "UINT", "FLOAT32", "FLOAT64", "BOOL", "STRING", "BYTE", "RUNE", "ERROR"]
        case .java:
            return ["INT", "LONG", "DOUBLE", "FLOAT", "BOOLEAN", "CHAR", "BYTE", "SHORT", "STRING", "OBJECT"]
        case .sql, .shell, .html, .css, .plaintext:
            return []
        }
    }

    private static func lineCommentMarkers(for language: SyntaxLanguage) -> [String] {
        switch language {
        case .python, .shell: return ["#"]
        case .sql: return ["--"]
        case .typescript, .javascript, .rust, .go, .java: return ["//"]
        case .html, .css, .plaintext: return []
        }
    }

    private static func blockCommentMarkers(for language: SyntaxLanguage) -> [(start: String, end: String)] {
        switch language {
        case .typescript, .javascript, .rust, .go, .java, .css: return [("/*", "*/")]
        case .html: return [("<!--", "-->")]
        case .python, .shell, .sql, .plaintext: return []
        }
    }

    private static func stringDelimiters(for language: SyntaxLanguage) -> Set<Character> {
        switch language {
        case .typescript, .javascript, .java, .go, .rust, .sql, .python, .shell:
            return ["\"", "'"]
        case .html, .css, .plaintext:
            return []
        }
    }
}
