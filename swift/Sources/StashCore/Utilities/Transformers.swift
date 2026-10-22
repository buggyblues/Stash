import Foundation

/// Text transformations offered by the preview toolbar.
public enum Transformers {
    public static func upper(_ text: String) -> String { text.uppercased() }

    public static func lower(_ text: String) -> String { text.lowercased() }

    /// Title cases the first word character of every word.
    ///
    /// Word characters are ASCII letters, digits and underscores; every other
    /// character (including non-ASCII letters) acts as a word boundary.
    public static func title(_ text: String) -> String {
        var result = ""
        var previousWasWordCharacter = false
        for character in text {
            let isWordCharacter = character.isASCII && (character.isLetter || character.isNumber || character == "_")
            if isWordCharacter {
                result.append(previousWasWordCharacter ? character : Character(character.uppercased()))
            } else {
                result.append(character)
            }
            previousWasWordCharacter = isWordCharacter
        }
        return result
    }

    /// `foo bar-baz_qux` → `fooBarBazQux`
    public static func camel(_ text: String) -> String {
        // Collapse runs of `-`, `_` or whitespace, upper-casing the following character.
        var collapsed = ""
        var upperNext = false
        for character in text {
            if character == "-" || character == "_" || character.isWhitespace {
                upperNext = true
            } else {
                collapsed.append(upperNext ? Character(character.uppercased()) : character)
                upperNext = false
            }
        }
        // Lower-case a leading capital, matching the original implementation.
        if let first = collapsed.first, first.isUppercase {
            collapsed.replaceSubrange(collapsed.startIndex..<collapsed.index(after: collapsed.startIndex),
                                      with: String(first).lowercased())
        }
        return collapsed
    }

    /// `fooBar` → `foo_bar`
    ///
    /// Dashes and whitespace collapse into `_`; underscores are left untouched.
    public static func snake(_ text: String) -> String {
        insertSeparators(in: text, separator: "_", folded: ["-"], whitespace: true)
    }

    /// `fooBar` → `foo-bar`
    ///
    /// Underscores and whitespace collapse into `-`; dashes are left untouched.
    public static func kebab(_ text: String) -> String {
        insertSeparators(in: text, separator: "-", folded: ["_"], whitespace: true)
    }

    public static func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func removeAllWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }

    /// The transformations exposed in the preview toolbar.
    public static let all: [(key: String, labelKey: String, transform: (String) -> String)] = [
        ("upper", "preview.toolbar.upper", Transformers.upper),
        ("lower", "preview.toolbar.lower", Transformers.lower),
        ("title", "preview.toolbar.title", Transformers.title),
        ("camel", "preview.toolbar.camel", Transformers.camel),
        ("snake", "preview.toolbar.snake", Transformers.snake),
        ("kebab", "preview.toolbar.kebab", Transformers.kebab),
        ("trim", "preview.toolbar.trim", Transformers.trim),
        ("noSpace", "preview.toolbar.noSpace", Transformers.removeAllWhitespace)
    ]

    /// Inserts `separator` between a lower-case and an upper-case letter and
    /// folds runs of the characters listed in `folded` (plus whitespace when
    /// requested) into a single `separator`.
    private static func insertSeparators(in text: String, separator: String, folded: [Character], whitespace: Bool) -> String {
        var result = ""
        let characters = Array(text)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            // A run of folded characters (or whitespace) becomes one separator.
            let isFolded = folded.contains(character) || (whitespace && character.isWhitespace)
            if isFolded {
                while index < characters.count {
                    let next = characters[index]
                    let nextIsFolded = folded.contains(next) || (whitespace && next.isWhitespace)
                    guard nextIsFolded else { break }
                    index += 1
                }
                result.append(separator)
                continue
            }

            // A lower-case letter directly followed by an upper-case letter is split.
            if character.isLowercase,
               index + 1 < characters.count,
               characters[index + 1].isUppercase {
                result.append(character)
                result.append(separator)
                result.append(characters[index + 1])
                index += 2
                continue
            }

            result.append(character)
            index += 1
        }

        return result.lowercased()
    }
}
