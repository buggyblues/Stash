import XCTest
@testable import StashCore

final class ElectronSettingsImportTests: XCTestCase {
    func testImportsLatestRecordWithoutReadingUserData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let records = "zpaste-settings" + "{\"theme\":\"light\",\"accentColor\":\"#123456\"}"
            + "zpaste-settings" + "{\"theme\":\"dark\",\"layoutMode\":\"bottom\"}"
        try Data(records.utf8).write(to: directory.appendingPathComponent("000001.log"))
        let settings = try XCTUnwrap(ElectronSettingsImporter.loadSettings(directory: directory))
        XCTAssertEqual(settings["theme"] as? String, "dark")
        XCTAssertEqual(settings["layoutMode"] as? String, "bottom")
    }
}
