import XCTest
@testable import StashCore

final class SyncRegressionTests: XCTestCase {
    func makeRepository() throws -> Repository {
        let db = try SQLiteConnection(path: ":memory:")
        try Schema.createTables(in: db)
        return Repository(db: db)
    }

    func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    func sync(_ repo: Repository, _ directory: URL) -> ICloudSync {
        ICloudSync(repository: repo, syncDirectory: directory.appendingPathComponent("cloud"),
                   stateURL: directory.appendingPathComponent("state.json"),
                   deviceIdURL: directory.appendingPathComponent("device-id"))
    }

    func testImportsElectronNumericFlagsAndPreservesLocalTagRelationships() throws {
        try withDirectory { directory in
            let repo = try makeRepository()
            let entry = ClipboardItem(id: "local", content: "hello", contentType: "text", contentHash: "same",
                                      title: "local title", createdAt: 1, updatedAt: 2)
            try repo.insertItem(entry)
            try repo.applyTags(itemId: "local", slugs: ["work"])
            let cloud = directory.appendingPathComponent("cloud")
            try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
            var remote = try XCTUnwrap(repo.getItemById("local"))
            remote.id = "remote-id"
            remote.isPinned = true
            remote.title = "remote title"
            remote.updatedAt += 100
            let file = SyncFile(deviceId: "other", changes: [SyncChange(operation: "update", item: remote,
                timestamp: remote.updatedAt, deviceId: "other")], exportedAt: remote.updatedAt)
            try JSONEncoder().encode(file).write(to: cloud.appendingPathComponent("sync_other_1.json"))
            let service = sync(repo, directory)
            service.importChanges()
            XCTAssertEqual(try repo.getItemCount(), 1)
            XCTAssertEqual(try repo.getItemTagSlugs("local"), ["work"])
            XCTAssertEqual(try repo.getItemById("local")?.title, "remote title")
            XCTAssertTrue(try XCTUnwrap(repo.getItemById("local")).isPinned)
        }
    }

    func testFailedImportRollsBackAndCanRetrySameFile() throws {
        try withDirectory { directory in
            let repo = try makeRepository()
            let cloud = directory.appendingPathComponent("cloud")
            try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
            let first = ClipboardItem(id: "one", content: "one", contentType: "text", contentHash: "one", createdAt: 1, updatedAt: 1)
            let second = ClipboardItem(id: "two", content: "two", contentType: "text", contentHash: "two", createdAt: 1, updatedAt: 1)
            try repo.connection.executeScript("CREATE TRIGGER reject_two BEFORE INSERT ON clipboard_items WHEN NEW.id = 'two' BEGIN SELECT RAISE(FAIL, 'test failure'); END;")
            func write(_ items: [ClipboardItem]) throws {
                let changes = items.map { SyncChange(operation: "add", item: $0, timestamp: 1, deviceId: "remote") }
                try JSONEncoder().encode(SyncFile(deviceId: "remote", changes: changes, exportedAt: 1))
                    .write(to: cloud.appendingPathComponent("sync_remote_1.json"))
            }
            try write([first, second])
            let service = sync(repo, directory)
            service.importChanges()
            XCTAssertEqual(try repo.getItemCount(), 0)
            try repo.connection.execute("DROP TRIGGER reject_two")
            try write([first, second])
            service.importChanges()
            XCTAssertEqual(try repo.getItemCount(), 2)
        }
    }

    func testExportIncludesMoreThan2000ItemsAndProducesAtomicDecodableFile() throws {
        try withDirectory { directory in
            let repo = try makeRepository()
            try repo.connection.transaction {
                for index in 0..<2005 {
                    try repo.insertItem(ClipboardItem(id: "id-\(index)", content: "text-\(index)", contentType: "text",
                        contentHash: "hash-\(index)", createdAt: 1, updatedAt: Int64(index + 1)))
                }
            }
            let service = sync(repo, directory)
            service.exportChanges()
            let cloud = directory.appendingPathComponent("cloud")
            let files = try FileManager.default.contentsOfDirectory(at: cloud, includingPropertiesForKeys: nil)
            XCTAssertEqual(files.count, 1)
            let file = try JSONDecoder().decode(SyncFile.self, from: Data(contentsOf: files[0]))
            XCTAssertEqual(file.changes.count, 2005)
        }
    }

    func testExportFailureDoesNotAdvanceCheckpoint() throws {
        try withDirectory { directory in
            let repo = try makeRepository()
            try repo.insertItem(ClipboardItem(id: "one", content: "hello", contentType: "text", contentHash: "one",
                                             createdAt: 1, updatedAt: 1))
            let cloud = directory.appendingPathComponent("cloud")
            try Data("blocks directory".utf8).write(to: cloud)
            let service = sync(repo, directory)
            service.fullSync()
            try FileManager.default.removeItem(at: cloud)
            service.exportChanges()
            let files = try FileManager.default.contentsOfDirectory(at: cloud, includingPropertiesForKeys: nil)
            XCTAssertEqual(files.count, 1)
        }
    }

    func testEncryptionReadsNodeAES256GCMFixtureAndRoundTrips() throws {
        // Produced by the original Node crypto settings: PBKDF2 SHA512 / 100000 / 32-byte key / 16-byte IV.
        let fixture = EncryptedPayload(ciphertext: "mw5bDeCUlyqfbFu12Q+GDUEWg8w59U3L3B6ZkMmYDbGftw==",
            iv: "CQkJCQkJCQkJCQkJCQkJCQ==", tag: "3aWIiXXdCJBqpLEzDx7Vuw==",
            salt: "BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc=")
        XCTAssertEqual(try Encryption.decryptWithPassword(fixture, password: "Stash-test-密码"), "兼容 Electron 😀\n{\"text\":\"ok\"}")
        XCTAssertThrowsError(try Encryption.decryptWithPassword(fixture, password: "wrong"))
        let generated = try Encryption.encryptWithPassword("roundtrip", password: "test")
        XCTAssertEqual(try Encryption.decryptWithPassword(generated, password: "test"), "roundtrip")
    }

    func testLegacyTagsMigrateOnlyOnceAndRetentionKeepsProtectedItems() throws {
        let repo = try makeRepository()
        for id in ["tagged", "pinned", "favorite", "expired"] {
            try repo.insertItem(ClipboardItem(id: id, content: id, contentType: "text", contentHash: id,
                                             createdAt: 1, updatedAt: 1))
        }
        try repo.connection.execute("UPDATE clipboard_items SET tags = ? WHERE id = ?", [.text("[\"legacy\"]"), .text("tagged")])
        try Schema.createTables(in: repo.connection)
        XCTAssertEqual(try repo.getItemTagSlugs("tagged"), ["legacy"])
        try repo.removeTag(itemId: "tagged", slug: "legacy")
        try Schema.createTables(in: repo.connection)
        XCTAssertTrue(try repo.getItemTagSlugs("tagged").isEmpty)
        try repo.applyTags(itemId: "tagged", slugs: ["keep"])
        try repo.connection.execute("UPDATE clipboard_items SET is_pinned = 1 WHERE id = 'pinned'")
        try repo.connection.execute("UPDATE clipboard_items SET is_favorite = 1 WHERE id = 'favorite'")
        try repo.cleanupByRetention(days: 1)
        XCTAssertEqual(Set(try repo.getItems().map(\.id)), ["tagged", "pinned", "favorite"])
    }

    func testBackupContainsLiveDatabaseAndTags() throws {
        try withDirectory { directory in
            let repo = try makeRepository()
            try repo.insertItem(ClipboardItem(id: "backup", content: "keep me", contentType: "text", contentHash: "backup",
                                             createdAt: 1, updatedAt: 1))
            try repo.applyTags(itemId: "backup", slugs: ["keep"])
            let destination = directory.appendingPathComponent("backup.sqlite3")
            try repo.connection.backup(to: destination)
            let restored = Repository(db: try SQLiteConnection(path: destination.path))
            XCTAssertEqual(try restored.getItemById("backup")?.content, "keep me")
            XCTAssertEqual(try restored.getItemTagSlugs("backup"), ["keep"])
        }
    }

    func testSettingsPersistenceDoesNotReadHostProfile() throws {
        let name = "StashTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(defaults: defaults, importLegacy: false)
        store.maxItems = 0
        store.layoutMode = .bottom
        store.widgetFollowFilter = true
        store.customShortcut = "Control+Shift+V"
        let restored = SettingsStore(defaults: defaults, importLegacy: false)
        XCTAssertEqual(restored.maxItems, 0)
        XCTAssertEqual(restored.layoutMode, .bottom)
        XCTAssertTrue(restored.widgetFollowFilter)
        XCTAssertEqual(restored.customShortcut, "Control+Shift+V")
    }
}
