import Foundation

/// A single change exported to the sync folder.
public struct SyncChange: Codable, Equatable, Sendable {
    public var operation: String // "add" | "update" | "delete"
    public var item: ClipboardItem
    public var timestamp: Int64
    public var deviceId: String

    public init(operation: String, item: ClipboardItem, timestamp: Int64, deviceId: String) {
        self.operation = operation
        self.item = item
        self.timestamp = timestamp
        self.deviceId = deviceId
    }
}

/// The plaintext sync file written into the iCloud Drive folder.
public struct SyncFile: Codable, Equatable, Sendable {
    public var deviceId: String
    public var changes: [SyncChange]
    public var exportedAt: Int64

    public init(deviceId: String, changes: [SyncChange], exportedAt: Int64) {
        self.deviceId = deviceId
        self.changes = changes
        self.exportedAt = exportedAt
    }
}

/// The encrypted sync file (version 2).
public struct EncryptedSyncFile: Codable, Equatable, Sendable {
    public var version: Int
    public var encrypted: Bool
    public var data: EncryptedPayload

    public init(version: Int, encrypted: Bool, data: EncryptedPayload) {
        self.version = version
        self.encrypted = encrypted
        self.data = data
    }
}

/// Local bookkeeping for the sync loop.
public struct SyncState: Codable, Equatable, Sendable {
    public var lastSyncTime: Int64
    public var processedFiles: [String]

    public init(lastSyncTime: Int64 = 0, processedFiles: [String] = []) {
        self.lastSyncTime = lastSyncTime
        self.processedFiles = processedFiles
    }
}

/// Synchronises the clipboard history through an iCloud Drive folder.
///
/// The on-disk format matches the previous implementation exactly, so folders
/// written by the Electron build can be imported and vice versa.
public final class ICloudSync {
    private let repository: Repository
    private let syncDirectory: URL
    private let stateURL: URL
    private let deviceIdURL: URL

    private var timer: Timer?
    private var lastSyncTime: Int64 = 0
    private var processedFiles: Set<String> = []
    private var syncPassword: String?
    public var onImported: (() -> Void)?

    /// The interval between two automatic syncs.
    public static let syncInterval: TimeInterval = 5 * 60

    public init(
        repository: Repository,
        syncDirectory: URL = AppPaths.iCloudSyncDirectory,
        stateURL: URL = AppPaths.syncStateURL,
        deviceIdURL: URL = AppPaths.deviceIdURL
    ) {
        self.repository = repository
        self.syncDirectory = syncDirectory
        self.stateURL = stateURL
        self.deviceIdURL = deviceIdURL
        self.deviceId = Self.loadDeviceId(from: deviceIdURL)
        loadState()
    }

    /// The stable identifier of this device.
    public let deviceId: String

    public func setSyncPassword(_ password: String?) {
        syncPassword = password
    }

    // MARK: - Lifecycle

    public func start() {
        guard timer == nil else { return }
        ensureSyncDirectory()
        fullSync()
        let timer = Timer(timeInterval: Self.syncInterval, repeats: true) { [weak self] _ in
            self?.exportChanges()
            self?.importChanges()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func fullSync() {
        exportChanges()
        importChanges()
    }

    public func syncNow() {
        exportChanges()
        importChanges()
    }

    // MARK: - Export

    public func exportChanges() {
        do {
            ensureSyncDirectory()
            cleanupOldSyncFiles()

            let boundary = Self.now()
            let items = try repository.getItems(options: GetItemsOptions(limit: -1))
            let changes: [SyncChange] = items
                .filter { $0.updatedAt >= lastSyncTime && $0.updatedAt <= boundary }
                .map { item in
                    SyncChange(
                        operation: "add",
                        item: item,
                        timestamp: item.updatedAt,
                        deviceId: deviceId
                    )
                }

            guard !changes.isEmpty else { return }

            let syncFile = SyncFile(deviceId: deviceId, changes: changes, exportedAt: Self.now())
            let filename = "sync_\(deviceId)_\(Self.now())_\(UUID().uuidString.prefix(8)).json"

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let plaintext = try encoder.encode(syncFile)
            let data: Data
            if let password = syncPassword {
                guard let plaintextString = String(data: plaintext, encoding: .utf8),
                      let payload = try? Encryption.encryptWithPassword(plaintextString, password: password)
                else { return }
                let encrypted = EncryptedSyncFile(version: 2, encrypted: true, data: payload)
                data = try encoder.encode(encrypted)
            } else {
                data = plaintext
            }

            try data.write(to: syncDirectory.appendingPathComponent(filename), options: .atomic)
            lastSyncTime = boundary
            saveState()
        } catch {
            NSLog("[iCloudSync] export error: \(error.localizedDescription)")
        }
    }

    // MARK: - Import

    public func importChanges() {
        do {
            ensureSyncDirectory()
            let files = try FileManager.default.contentsOfDirectory(atPath: syncDirectory.path)
                .filter { $0.hasPrefix("sync_") && $0.hasSuffix(".json") && !$0.contains(deviceId) }
                .sorted()

            for file in files where !processedFiles.contains(file) {
                do {
                    let url = syncDirectory.appendingPathComponent(file)
                    let content = try String(contentsOf: url, encoding: .utf8)
                    guard let syncFile = parseSyncFile(content) else { continue }
                    try repository.connection.transaction {
                        for change in syncFile.changes { try apply(change) }
                    }
                    processedFiles.insert(file)
                    onImported?()
                } catch {
                    NSLog("[iCloudSync] failed to import \(file)")
                }
            }

            saveState()
        } catch {
            NSLog("[iCloudSync] import error: \(error.localizedDescription)")
        }
    }

    /// Parses a sync file, handling both the encrypted v2 and legacy formats.
    func parseSyncFile(_ content: String) -> SyncFile? {
        guard let data = content.data(using: .utf8) else { return nil }

        if let encrypted = try? JSONDecoder().decode(EncryptedSyncFile.self, from: data) {
            guard encrypted.version == 2, encrypted.encrypted else { return nil }
            guard let password = syncPassword else { return nil }
            guard let plaintext = try? Encryption.decryptWithPassword(encrypted.data, password: password),
                  let plaintextData = plaintext.data(using: .utf8),
                  let file = try? JSONDecoder().decode(SyncFile.self, from: plaintextData)
            else { return nil }
            return file
        }

        // Legacy plaintext format.
        if let file = try? JSONDecoder().decode(SyncFile.self, from: data) {
            return file
        }
        return nil
    }

    /// Resolves a conflict between the local and the remote copy of an item.
    public func resolveConflict(local: ClipboardItem, remote: ClipboardItem) -> ClipboardItem {
        remote.updatedAt > local.updatedAt ? remote : local
    }

    private func apply(_ change: SyncChange) throws {
        switch change.operation {
        case "add", "update":
            let existing = try repository.getItemByHash(change.item.contentHash)
                ?? repository.getItemById(change.item.id)
            var merged = change.item
            if let existing {
                merged = resolveConflict(local: existing, remote: change.item)
                merged.id = existing.id
                merged.isFavorite = existing.isFavorite || change.item.isFavorite
                merged.isPinned = existing.isPinned || change.item.isPinned
                merged.updatedAt = max(existing.updatedAt, change.item.updatedAt)
                try repository.updateItem(merged)
            } else {
                try repository.insertItem(merged)
            }
            let slugs = change.item.tagSlugList
            if !slugs.isEmpty { try repository.applyTags(itemId: merged.id, slugs: slugs) }
        case "delete":
            if let existing = try repository.getItemById(change.item.id), existing.updatedAt <= change.timestamp {
                try repository.deleteItem(existing.id)
            }
        default:
            break
        }
    }

    // MARK: - Housekeeping

    private func ensureSyncDirectory() {
        try? FileManager.default.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
    }

    private func cleanupOldSyncFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: syncDirectory.path) else { return }
        let ownFiles = files
            .filter { $0.hasPrefix("sync_\(deviceId)_") && $0.hasSuffix(".json") }
            .sorted()

        if ownFiles.count > 5 {
            for file in ownFiles.prefix(ownFiles.count - 5) {
                try? FileManager.default.removeItem(at: syncDirectory.appendingPathComponent(file))
            }
        }

        // Drop bookkeeping entries for files that no longer exist.
        let remaining = Set(files)
        processedFiles = processedFiles.filter { remaining.contains($0) }
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(SyncState.self, from: data)
        else { return }
        lastSyncTime = state.lastSyncTime
        processedFiles = Set(state.processedFiles)
    }

    private func saveState() {
        let state = SyncState(lastSyncTime: lastSyncTime, processedFiles: Array(processedFiles))
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: stateURL, options: .atomic)
    }

    private static func loadDeviceId(from url: URL) -> String {
        if let existing = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let host = ProcessInfo.processInfo.hostName
        let identifier = "device_\(host)_\(Self.now())_\(String(UUID().uuidString.prefix(8)))"
        try? identifier.write(to: url, atomically: true, encoding: .utf8)
        return identifier
    }

    private static func now() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
