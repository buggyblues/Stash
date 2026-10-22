import Foundation

/// Splits a JSON document into coloured tokens.
///
/// The key detection mirrors the previous implementation: a quoted fragment is
/// treated as a key when the document contains the same fragment followed by a
/// colon.
public enum JSONColorizer {
    /// A coloured fragment of a JSON document.
    public struct Fragment: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case key
            case string
            case number
            case boolean
            case null
            case punctuation
        }

        public var kind: Kind
        public var text: String

        public init(kind: Kind, text: String) {
            self.kind = kind
            self.text = text
        }
    }

    /// Tokenizes a JSON document.
    public static func tokenize(_ json: String) -> [Fragment] {
        var fragments: [Fragment] = []
        let segments = splitQuotedSegments(json)

        for segment in segments {
            if segment.isQuoted {
                let inner = String(segment.text.dropFirst().dropLast())
                if isKey(inner, in: json) {
                    fragments.append(Fragment(kind: .key, text: segment.text))
                } else {
                    fragments.append(Fragment(kind: .string, text: segment.text))
                }
                continue
            }

            // Split the non quoted part into literals and punctuation.
            var buffer = ""
            var characters = Array(segment.text)
            var index = 0

            func flush() {
                if !buffer.isEmpty {
                    fragments.append(Fragment(kind: classify(buffer), text: buffer))
                    buffer = ""
                }
            }

            while index < characters.count {
                let character = characters[index]
                if character.isLetter || character.isNumber || character == "." || character == "-" || character == "+" {
                    buffer.append(character)
                } else {
                    flush()
                    fragments.append(Fragment(kind: .punctuation, text: String(character)))
                }
                index += 1
            }
            flush()
        }

        return fragments
    }

    private static func classify(_ literal: String) -> Fragment.Kind {
        switch literal {
        case "true", "false": return .boolean
        case "null": return .null
        default: break
        }
        if literal.range(of: "^\\d+\\.?\\d*$", options: .regularExpression) != nil {
            return .number
        }
        return .punctuation
    }

    private static func isKey(_ inner: String, in document: String) -> Bool {
        document.contains("\"\(inner)\":")
    }

    private struct Segment {
        let text: String
        let isQuoted: Bool
    }

    /// Splits the document into quoted and non quoted parts.
    private static func splitQuotedSegments(_ json: String) -> [Segment] {
        var segments: [Segment] = []
        var current = ""
        var index = json.startIndex

        while index < json.endIndex {
            let character = json[index]
            if character == "\"" {
                // Consume the whole quoted string, honouring escapes.
                var quoted = "\""
                index = json.index(after: index)
                while index < json.endIndex {
                    let next = json[index]
                    quoted.append(next)
                    index = json.index(after: index)
                    if next == "\\" {
                        if index < json.endIndex {
                            quoted.append(json[index])
                            index = json.index(after: index)
                        }
                        continue
                    }
                    if next == "\"" { break }
                }
                if !current.isEmpty {
                    segments.append(Segment(text: current, isQuoted: false))
                    current = ""
                }
                segments.append(Segment(text: quoted, isQuoted: true))
                continue
            }
            current.append(character)
            index = json.index(after: index)
        }

        if !current.isEmpty {
            segments.append(Segment(text: current, isQuoted: false))
        }
        return segments
    }
}
