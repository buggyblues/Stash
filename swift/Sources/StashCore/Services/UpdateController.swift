import AppKit
import Combine
import Foundation

/// The phases of the update flow.
public enum UpdatePhase: Equatable {
    case idle
    case checking
    case upToDate
    case available
    case downloading
    case downloaded
    case error
    case downloadError
}

/// Checks for, downloads and installs new releases from GitHub.
public final class UpdateController: NSObject, ObservableObject {
    /// The GitHub repository releases are pulled from.
    public struct Repository: Sendable {
        public var owner: String
        public var name: String

        public init(owner: String, name: String) {
            self.owner = owner
            self.name = name
        }

        var releasesURL: URL {
            URL(string: "https://api.github.com/repos/\(owner)/\(name)/releases/latest")!
        }
    }

    @Published public private(set) var phase: UpdatePhase = .idle
    @Published public private(set) var newVersion = ""
    @Published public private(set) var percent: Double = 0
    @Published public private(set) var bytesPerSecond: Double = 0
    @Published public private(set) var errorMessage = ""

    public let currentVersion: String
    private let repository: Repository

    /// Called when a new release was found.
    public var onUpdateAvailable: ((String) -> Void)?
    /// Called when the release was downloaded and is ready to install.
    public var onUpdateDownloaded: (() -> Void)?
    /// Called when the download failed.
    public var onUpdateFailed: ((String) -> Void)?
    private var session: URLSession!
    private var downloadTask: URLSessionDownloadTask?
    private var downloadedFile: URL?
    private var lastTimestamp: Date?
    private var lastReceived: Int64 = 0
    private var assetURL: URL?
    private var isInstalling = false

    public init(currentVersion: String, repository: Repository = Repository(owner: "buggyblues", name: "Stash")) {
        self.currentVersion = currentVersion
        self.repository = repository
        super.init()

        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    // MARK: - Check

    /// Checks whether a newer release is available.
    public func check() {
        guard phase != .checking, phase != .downloading, phase != .downloaded else { return }
        phase = .checking
        errorMessage = ""

        var request = URLRequest(url: repository.releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Stash/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.phase = .error
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                      let data,
                      let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = payload["tag_name"] as? String
                else {
                    self.phase = .error
                    self.errorMessage = "checkFailed"
                    return
                }
                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                guard Self.isNewer(latest, than: self.currentVersion) else {
                    self.phase = .upToDate
                    return
                }
                self.assetURL = Self.releaseAsset(payload, architecture: self.currentArchitecture)
                self.newVersion = latest
                self.phase = .available
                self.onUpdateAvailable?(latest)
            }
        }.resume()
    }

    // MARK: - Download

    /// Downloads the new release.
    public func download() {
        phase = .downloading
        percent = 0
        bytesPerSecond = 0
        errorMessage = ""

        lastTimestamp = nil
        lastReceived = 0
        guard let url = assetURL else {
            phase = .downloadError
            errorMessage = "No compatible macOS ZIP asset in this release."
            return
        }

        let task = session.downloadTask(with: url)
        downloadTask = task
        task.resume()
    }

    /// Installs the downloaded release and restarts the app.
    public func install() {
        guard !isInstalling, let downloadedFile else { return }
        isInstalling = true
        let manager = FileManager.default
        let temporaryDirectory = manager.temporaryDirectory.appendingPathComponent("stash-update-\(UUID().uuidString)")
        let target = Bundle.main.bundleURL
        let stage = target.deletingLastPathComponent().appendingPathComponent(".Stash-stage-\(UUID().uuidString).app")
        let backup = target.deletingLastPathComponent().appendingPathComponent(".Stash-backup-\(UUID().uuidString).app")
        defer {
            try? manager.removeItem(at: temporaryDirectory)
            try? manager.removeItem(at: stage)
        }
        do {
            try manager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            try unzip(downloadedFile, into: temporaryDirectory)
            guard let candidate = try manager.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil)
                    .first(where: { $0.pathExtension == "app" }),
                  let bundle = Bundle(url: candidate), bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
                  bundle.infoDictionary?["CFBundleShortVersionString"] as? String == newVersion,
                  let executable = bundle.executableURL, manager.isExecutableFile(atPath: executable.path),
                  target.pathExtension == "app"
            else { throw UpdateError.invalidArchive }
            let verify = Process()
            verify.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            verify.arguments = ["--verify", "--deep", "--strict", candidate.path]
            verify.standardOutput = FileHandle.nullDevice
            verify.standardError = FileHandle.nullDevice
            try verify.run()
            verify.waitUntilExit()
            guard verify.terminationStatus == 0 else { throw UpdateError.invalidArchive }
            try manager.copyItem(at: candidate, to: stage)
            try manager.moveItem(at: target, to: backup)
            do {
                try manager.moveItem(at: stage, to: target)
            } catch {
                try manager.moveItem(at: backup, to: target)
                throw error
            }
            // Retain the backup until the replacement has launched successfully.
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: target, configuration: configuration) { application, error in
                DispatchQueue.main.async {
                    self.isInstalling = false
                    if application != nil, error == nil {
                        try? manager.removeItem(at: backup)
                        self.phase = .idle
                        self.downloadedFile = nil
                        NSApp.terminate(nil)
                    } else {
                        try? manager.removeItem(at: target)
                        try? manager.moveItem(at: backup, to: target)
                        self.phase = .downloadError
                        self.errorMessage = error?.localizedDescription ?? "Failed to launch update."
                    }
                }
            }
        } catch {
            isInstalling = false
            phase = .downloadError
            errorMessage = error.localizedDescription
        }
    }

    public static func isNewer(_ version: String, than current: String) -> Bool {
        func components(_ value: String) -> [Int]? {
            let raw = value.hasPrefix("v") ? String(value.dropFirst()) : value
            guard !raw.isEmpty, !raw.contains("-") else { return nil }
            let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
            let numbers = parts.compactMap { Int($0) }
            return numbers.count == parts.count ? numbers : nil
        }
        guard let candidate = components(version), let installed = components(current) else { return false }
        for index in 0..<max(candidate.count, installed.count) {
            let lhs = index < candidate.count ? candidate[index] : 0
            let rhs = index < installed.count ? installed[index] : 0
            if lhs != rhs { return lhs > rhs }
        }
        return false
    }

    static func releaseAsset(_ payload: [String: Any], architecture: String) -> URL? {
        let assets = payload["assets"] as? [[String: Any]] ?? []
        for asset in assets {
            guard let name = (asset["name"] as? String)?.lowercased(), name.hasSuffix(".zip"),
                  name.contains("stash"), name.contains(architecture) || name.contains("universal"),
                  let address = asset["browser_download_url"] as? String,
                  let url = URL(string: address), url.scheme == "https", url.host == "github.com"
            else { continue }
            return url
        }
        return nil
    }

    private var currentArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x64"
        #endif
    }

    /// Extracts a zip archive using the system `ditto` tool.
    private func unzip(_ archive: URL, into directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, directory.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError.invalidArchive
        }
    }
}

// MARK: - Download delegate

extension UpdateController: URLSessionDownloadDelegate {
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        DispatchQueue.main.async {
            if totalBytesExpectedToWrite > 0 {
                self.percent = min(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100, 100)
            }
            let now = Date()
            if let last = self.lastTimestamp {
                let elapsed = now.timeIntervalSince(last)
                if elapsed > 0 {
                    self.bytesPerSecond = Double(totalBytesWritten - self.lastReceived) / elapsed
                }
            }
            self.lastTimestamp = now
            self.lastReceived = totalBytesWritten
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let response = downloadTask.response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            DispatchQueue.main.async {
                self.phase = .downloadError
                self.errorMessage = "The release download failed."
            }
            return
        }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("stash-update-\(UUID().uuidString).zip")
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            DispatchQueue.main.async {
                self.downloadedFile = destination
                self.percent = 100
                self.phase = .downloaded
                self.onUpdateDownloaded?()
            }
        } catch {
            DispatchQueue.main.async {
                self.phase = .downloadError
                self.errorMessage = error.localizedDescription
            }
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        DispatchQueue.main.async {
            if self.phase == .downloading {
                self.phase = .downloadError
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

/// Errors raised while installing an update.
public enum UpdateError: Error, CustomStringConvertible {
    case invalidArchive

    public var description: String {
        switch self {
        case .invalidArchive: return "The downloaded archive does not contain an application bundle."
        }
    }
}
