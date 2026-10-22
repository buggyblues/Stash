import Foundation

/// Imports the settings of the previous Electron build.
///
/// The Electron app kept its settings in the Chromium `localStorage`, which
/// lives in a leveldb database. The value is read out of the leveldb files
/// with a best effort scan and is applied when the native app has no settings
/// of its own yet.
public enum ElectronSettingsImporter {
    /// The key the settings were stored under.
    public static let storageKey = "zpaste-settings"

    /// The leveldb folder of the previous build.
    public static var levelDBDirectory: URL {
        AppPaths.supportDirectory.appendingPathComponent("Local Storage/leveldb", isDirectory: true)
    }

    /// The settings of the previous build, if they can be recovered.
    public static func loadSettings(directory: URL = levelDBDirectory) -> [String: Any]? {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return nil }

        let candidates = files.filter { ["log", "ldb", "sst"].contains($0.pathExtension) }.sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhs == rhs ? $0.lastPathComponent > $1.lastPathComponent : lhs > rhs
        }
        for file in candidates {
            guard let data = try? Data(contentsOf: file) else { continue }
            if let settings = extractSettings(from: data) {
                return settings
            }
        }
        return nil
    }

    /// Scans a leveldb file for the settings record.
    private static func extractSettings(from data: Data) -> [String: Any]? {
        let keyBytes = Array(storageKey.utf8)
        let bytes = [UInt8](data)

        var result: [String: Any]?
        var index = 0
        while index + keyBytes.count <= bytes.count {
            if matches(bytes, keyBytes, at: index) {
                if let settings = readJSONObject(bytes, from: index + keyBytes.count) {
                    result = settings
                }
            }
            index += 1
        }
        return result
    }

    private static func matches(_ bytes: [UInt8], _ pattern: [UInt8], at index: Int) -> Bool {
        guard index + pattern.count <= bytes.count else { return false }
        for offset in 0..<pattern.count where bytes[index + offset] != pattern[offset] {
            return false
        }
        return true
    }

    /// Reads the JSON object that follows the key.
    private static func readJSONObject(_ bytes: [UInt8], from start: Int) -> [String: Any]? {
        var index = start
        // Skip the leveldb value markers and the key separator.
        while index < bytes.count, bytes[index] != UInt8(ascii: "{") {
            if bytes[index] == UInt8(ascii: "}") { return nil }
            index += 1
            if index - start > 4096 { return nil }
        }
        guard index < bytes.count else { return nil }

        var depth = 0
        var inString = false
        var escaped = false
        var end = index

        scan: while end < bytes.count {
            let byte = bytes[end]
            if inString {
                if escaped { escaped = false }
                else if byte == UInt8(ascii: "\\") { escaped = true }
                else if byte == UInt8(ascii: "\"") { inString = false }
            } else {
                switch byte {
                case UInt8(ascii: "\""):
                    inString = true
                case UInt8(ascii: "{"):
                    depth += 1
                case UInt8(ascii: "}"):
                    depth -= 1
                    if depth == 0 {
                        end += 1
                        break scan
                    }
                default:
                    break
                }
            }
            end += 1
        }

        guard depth == 0, end > index, end <= bytes.count else { return nil }
        let text = String(decoding: bytes[index..<end], as: UTF8.self)
        guard let data = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
