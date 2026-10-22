import Foundation

/// Resolves the icon of the application a clipboard item came from.
///
/// The lookup mirrors the previous implementation: Spotlight locates the app
/// bundle, the bundle's `Info.plist` names the icon file, and `sips` converts
/// the `.icns` into a 32×32 PNG which is cached on disk.
public final class AppIconResolver: @unchecked Sendable {
    private var memoryCache: [String: String?] = [:]
    private let cacheDirectory: URL
    private let lock = NSLock()

    public init(cacheDirectory: URL = AppPaths.appIconsDirectory) {
        self.cacheDirectory = cacheDirectory
    }

    /// Returns the base64 encoded PNG for a bundle identifier, or `nil`.
    ///
    /// The method is safe to call from multiple threads: the in memory cache is
    /// guarded by a lock. Icon conversion is serialized to avoid competing writes.
    public func icon(for bundleId: String) -> String? {
        guard !bundleId.isEmpty, bundleId.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else { return nil }

        lock.lock()
        defer { lock.unlock() }
        if let cached = memoryCache[bundleId] { return cached }
        let result = resolveIcon(for: bundleId)
        memoryCache[bundleId] = .some(result)
        return result
    }

    /// Removes a cached icon, e.g. after the user moved an application.
    public func invalidate(_ bundleId: String) {
        lock.lock()
        defer { lock.unlock() }
        memoryCache.removeValue(forKey: bundleId)
        try? FileManager.default.removeItem(at: cacheDirectory.appendingPathComponent("\(bundleId).png"))
    }

    // MARK: - Lookup

    private func resolveIcon(for bundleId: String) -> String? {
        let cachedPath = cacheDirectory.appendingPathComponent("\(bundleId).png")
        if let data = try? Data(contentsOf: cachedPath), !data.isEmpty {
            return data.base64EncodedString()
        }

        guard let iconPath = locateIconFile(for: bundleId) else { return nil }

        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        guard let converted = convertIcon(at: iconPath, to: cachedPath),
              let data = try? Data(contentsOf: converted), !data.isEmpty
        else { return nil }

        return data.base64EncodedString()
    }

    private func locateIconFile(for bundleId: String) -> URL? {
        guard let appPath = run("/usr/bin/mdfind", arguments: ["kMDItemCFBundleIdentifier == '\(bundleId)'"])
            .split(separator: "\n")
            .first
            .map(String.init),
              !appPath.isEmpty
        else { return nil }

        let appURL = URL(fileURLWithPath: appPath)
        let resources = appURL.appendingPathComponent("Contents/Resources")

        let iconFile = run("/usr/bin/defaults", arguments: ["read", appURL.appendingPathComponent("Contents/Info").path, "CFBundleIconFile"])
        if !iconFile.isEmpty {
            let name = iconFile.hasSuffix(".icns") ? iconFile : "\(iconFile).icns"
            let candidate = resources.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        let fallback = resources.appendingPathComponent("AppIcon.icns")
        if FileManager.default.fileExists(atPath: fallback.path) {
            return fallback
        }
        return nil
    }

    private func convertIcon(at source: URL, to destination: URL) -> URL? {
        let status = runStatus(
            "/usr/bin/sips",
            arguments: ["-s", "format", "png", "-z", "32", "32", source.path, "--out", destination.path]
        )
        guard status == 0, FileManager.default.fileExists(atPath: destination.path) else { return nil }
        return destination
    }

    private func run(_ executable: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func runStatus(_ executable: String, arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
