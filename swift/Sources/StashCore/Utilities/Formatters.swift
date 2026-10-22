import Foundation

/// Formatting helpers used by the preview panel.
public enum Formatters {
    /// The outcome of a JSON parse attempt.
    public struct JSONResult: Equatable, Sendable {
        public var formatted: String
        public var valid: Bool
        public var error: String?

        public init(formatted: String, valid: Bool, error: String? = nil) {
            self.formatted = formatted
            self.valid = valid
            self.error = error
        }
    }

    /// The outcome of a Base64 decode attempt.
    public struct Base64Result: Equatable, Sendable {
        public var decoded: String
        public var valid: Bool

        public init(decoded: String, valid: Bool) {
            self.decoded = decoded
            self.valid = valid
        }
    }

    /// Pretty-prints a JSON document; returns the input untouched when invalid.
    ///
    /// The output matches `JSON.stringify(value, null, 2)`: two space indent,
    /// no space before the colon and the original key order.
    public static func formatJSON(_ input: String) -> JSONResult {
        guard let value = JSONValue.parse(input) else {
            return JSONResult(formatted: input, valid: false, error: "Invalid JSON")
        }
        return JSONResult(formatted: value.serialized(indent: 2), valid: true)
    }

    /// Decodes Base64 text. Invalid input yields an empty, invalid result.
    public static func decodeBase64(_ input: String) -> Base64Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = Data(base64Encoded: trimmed, options: [.ignoreUnknownCharacters]),
              data.count > 0 else {
            return Base64Result(decoded: "", valid: false)
        }
        // `atob` yields a latin-1 string, so decode the bytes the same way.
        if let text = String(data: data, encoding: .isoLatin1) {
            return Base64Result(decoded: text, valid: true)
        }
        if let text = String(data: data, encoding: .utf8) {
            return Base64Result(decoded: text, valid: true)
        }
        return Base64Result(decoded: "", valid: false)
    }

    public static func encodeBase64(_ input: String) -> String {
        Data(input.utf8).base64EncodedString()
    }

    public static func encodeURL(_ input: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return input.addingPercentEncoding(withAllowedCharacters: allowed) ?? input
    }

    public static func decodeURL(_ input: String) -> String {
        input.removingPercentEncoding ?? input
    }
}
