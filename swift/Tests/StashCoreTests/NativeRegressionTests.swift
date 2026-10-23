import AppKit
import SwiftUI
import XCTest
@testable import StashCore
@testable import StashUI
@testable import StashApp

final class NativeRegressionTests: XCTestCase {
    @MainActor func testNativeMenuProvidesCommandWToCloseCurrentWindow() async {
        let menu = MainMenuBuilder.build(language: .simplifiedChinese)
        let command = menu.items.compactMap(\.submenu).flatMap(\.items)
            .first { $0.action == #selector(NSWindow.performClose(_:)) }
        XCTAssertNotNil(command)
        XCTAssertEqual(command?.keyEquivalent, "w")
        XCTAssertEqual(command?.keyEquivalentModifierMask, .command)
        XCTAssertNil(command?.target)
    }

    func repository() throws -> Repository {
        let db = try SQLiteConnection(path: ":memory:")
        try Schema.createTables(in: db)
        return Repository(db: db)
    }

    func item(_ id: String, type: String = "text", timestamp: Int64 = 1) -> ClipboardItem {
        ClipboardItem(id: id, content: "payload-" + id, contentType: type, contentHash: "hash-" + id,
                      preview: "preview-" + id, createdAt: timestamp, updatedAt: timestamp)
    }

    @MainActor private func waitForPreview(_ id: String, in model: PanelViewModel,
                                          file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while model.previewItem?.id != id && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(model.previewItem?.id, id, file: file, line: line)
    }

    func testDefaultCarbonHotKeysUseMacVirtualCodes() {
        let expected: [String: UInt32] = ["Shift+CommandOrControl+V": 9, "CommandOrControl+J": 38,
            "Alt+W": 13, "Alt+1": 18, "Alt+5": 23, "Alt+9": 25,
            "CommandOrControl+;": 41, "CommandOrControl+\u{27}": 39]
        for (shortcut, code) in expected {
            XCTAssertEqual(HotKeyDescriptor(accelerator: shortcut)?.keyCode, code, shortcut)
        }
        XCTAssertNil(HotKeyDescriptor(accelerator: "Alt"))
        XCTAssertNil(HotKeyDescriptor(accelerator: "Invalid"))
    }

    func testFunctionKeyRegistrationAndUnknownModifiers() {
        XCTAssertEqual(HotKeyDescriptor(accelerator: "CommandOrControl+F13")?.keyCode, 105)
        XCTAssertEqual(HotKeyDescriptor(accelerator: "Alt+PageDown")?.keyCode, 121)
        XCTAssertNil(HotKeyDescriptor(accelerator: "Invalid+V"))
    }

    func testNativeNavigationAndOptionKeysAreNormalized() throws {
        for (code, key) in [(UInt16(125), "ArrowDown"), (126, "ArrowUp"), (53, "Escape"), (36, "Enter")] {
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: 0, windowNumber: 0, context: nil, characters: "\u{F700}", charactersIgnoringModifiers: "\u{F700}",
                isARepeat: false, keyCode: code))
            XCTAssertEqual(NativeKeyboard.info(for: event).key, key)
        }
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .option,
            timestamp: 0, windowNumber: 0, context: nil, characters: "∑", charactersIgnoringModifiers: "∑",
            isARepeat: false, keyCode: 13))
        XCTAssertTrue(Shortcut.matches(NativeKeyboard.info(for: event), "Alt+W"))
        XCTAssertEqual(Shortcut.definition(from: NativeKeyboard.info(for: event)), "Alt+W")
    }

    func testControlDoesNotMatchCommand() {
        XCTAssertTrue(Shortcut.matches(KeyEventInfo(key: "1", code: "Digit1", ctrlKey: true), "Control+1"))
        XCTAssertFalse(Shortcut.matches(KeyEventInfo(key: "1", code: "Digit1", metaKey: true), "Control+1"))
        XCTAssertFalse(Shortcut.matches(KeyEventInfo(key: "f", code: "KeyF", ctrlKey: true), "CommandOrControl+F"))
        XCTAssertNil(Shortcut.definition(from: KeyEventInfo(key: "")))
    }

    func testSQLitePreservesEmbeddedNullsAndUnicode() throws {
        let repo = try repository()
        var entry = item("unicode")
        entry.content = "你好\0after\n😀"
        try repo.insertItem(entry)
        XCTAssertEqual(try repo.getItemById(entry.id)?.content, entry.content)
    }

    func testSourceFilterAcceptsPrettyJsonAndLiteralWildcards() throws {
        let repo = try repository()
        var entry = item("source")
        entry.sourceApp = "{\"bundleId\": \"com.example_%\", \"name\": \"Example\"}"
        try repo.insertItem(entry)
        XCTAssertEqual(try repo.getItems(options: GetItemsOptions(sourceApp: "com.example_%")).count, 1)
        XCTAssertEqual(try repo.getContentTypeCounts(options: ContentTypeCountsOptions(sourceApp: "com.example_%"))["text"], 1)
        XCTAssertTrue(try repo.getItems(options: GetItemsOptions(sourceApp: "com.exampleXY")).isEmpty)
    }

    @MainActor func testSearchAndFiltersComposeAndNewCaptureRespectsFilter() async throws {
        let repo = try repository()
        try repo.insertItem(item("alpha"))
        try repo.insertItem(item("beta", type: "url"))
        let model = PanelViewModel(repository: repo)
        model.isVisible = true
        model.search("payload")
        XCTAssertEqual(model.items.count, 2)
        model.setFilterType("url")
        XCTAssertEqual(model.searchQuery, "payload")
        XCTAssertEqual(model.items.map(\.id), ["beta"])
        let new = item("new-text", timestamp: 10)
        try repo.insertItem(new)
        model.addItem(new)
        XCTAssertEqual(model.items.map(\.id), ["beta"])
        model.search("alpha")
        XCTAssertTrue(model.items.isEmpty)
    }

    @MainActor func testTaggedFavoriteAndPinnedOrderStayConsistentWithDatabase() async throws {
        let repo = try repository()
        try repo.insertItem(item("old", timestamp: 1))
        try repo.insertItem(item("new", timestamp: 2))
        try repo.applyTags(itemId: "old", slugs: ["work"])
        let model = PanelViewModel(repository: repo)
        model.loadItems()
        model.toggleFavorite("old")
        XCTAssertFalse(try XCTUnwrap(model.items.first { $0.id == "old" }).isFavorite)
        model.togglePin("new")
        XCTAssertEqual(model.items.first?.id, "new")
        model.setLeftFilter(.starred)
        XCTAssertTrue(model.items.isEmpty)
    }

    @MainActor func testPreviewFollowsReplacementAtSameIndexAndDeleteUpdatesCounts() async throws {
        let repo = try repository()
        try repo.insertItem(item("first", timestamp: 2))
        try repo.insertItem(item("second", timestamp: 1))
        try repo.toggleFavorite("first")
        let model = PanelViewModel(repository: repo)
        model.loadItems()
        try await waitForPreview("first", in: model)
        model.deleteItem("first")
        try await waitForPreview("second", in: model)
        XCTAssertEqual(model.starredCount, 0)
        XCTAssertEqual(model.typeCounts["text"], 1)
    }

    @MainActor func testPasteResolvesFullContentAndDeletedRowsNeverPasteEmptySummary() async throws {
        let repo = try repository()
        try repo.insertItem(item("full"))
        let model = PanelViewModel(repository: repo)
        model.loadItems()
        XCTAssertEqual(model.items.first?.content, "")
        var pasted: [ClipboardItem] = []
        model.onPaste = { pasted.append($0) }
        model.pasteItem("full")
        XCTAssertEqual(pasted.first?.content, "payload-full")
        try repo.deleteItem("full")
        model.pasteItem("full")
        XCTAssertEqual(pasted.count, 1)
    }

    @MainActor func testWidgetFollowFilterAndClosePreservePinState() async throws {
        let repo = try repository()
        try repo.insertItem(item("text"))
        try repo.insertItem(item("url", type: "url"))
        let model = WidgetViewModel(repository: repo)
        model.setFollowFilter(true)
        model.setFilter(.init(contentType: "url"))
        model.load()
        XCTAssertEqual(model.items.map(\.id), ["url"])
        model.close()
        XCTAssertTrue(model.isPinned)
    }

    @MainActor func testClipboardChangesCaptureOnceAndDuplicateImagesNotify() async throws {
        let repo = try repository()
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let monitor = ClipboardMonitor(repository: repo, pasteboard: pasteboard)
        var notifications = 0
        monitor.onNewItemHandler = { _ in notifications += 1 }
        pasteboard.setString("marker", forType: .string)
        monitor.poll()
        monitor.poll()
        XCTAssertEqual(try repo.getItemCount(), 1)
        XCTAssertEqual(notifications, 1)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.setColor(.red, atX: 0, y: 0)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        for _ in 0..<2 {
            pasteboard.clearContents()
            pasteboard.setData(png, forType: .png)
            monitor.poll()
        }
        XCTAssertEqual(try repo.getItemCount(), 2)
        XCTAssertEqual(notifications, 3)
        pasteboard.clearContents()
        pasteboard.setString("marker", forType: .string)
        monitor.poll()
        XCTAssertEqual(notifications, 4)
    }

    @MainActor func testQueueUsesResolvedContentDeduplicatesAndDoesNotConsumeWithoutPermission() async throws {
        let repo = try repository()
        try repo.insertItem(item("one"))
        try repo.insertItem(item("two"))
        var writes: [String] = []
        var permitted = false
        var pastes = 0
        let queue = SequenceQueueManager(repository: repo, writeItem: { content, _ in writes.append(content); return true },
            writeText: { writes.append($0) }, simulatePaste: { pastes += 1 }, canPaste: { permitted })
        queue.addMultiple(ids: ["one", "one", "missing", "two"])
        XCTAssertEqual(queue.count, 2)
        queue.pasteNext()
        XCTAssertTrue(writes.isEmpty)
        XCTAssertEqual(queue.count, 2)
        permitted = true
        queue.pasteNext()
        queue.pasteNext() // A second press must not overwrite the first payload before Cmd+V.
        XCTAssertEqual(writes, ["payload-one"])
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(pastes, 1)
        queue.pasteNext()
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(writes, ["payload-one", "payload-two"])
        XCTAssertEqual(queue.count, 0)
    }

    @MainActor func testSettingsWindowContentSurvivesFirstOpenAndCloseCallback() async throws {
        _ = NSApplication.shared
        let controller = SettingsWindowController()
        var closed = false
        controller.onClosed = { closed = true }
        controller.setContent(Text("Settings regression marker"))
        controller.open()
        XCTAssertTrue(controller.isVisible)
        controller.close()
        XCTAssertTrue(closed)
        XCTAssertFalse(controller.isVisible)
    }

    @MainActor func testSettingsWindowAppearanceAppliesBeforeFirstDisplayAndUpdates() throws {
        _ = NSApplication.shared
        let controller = SettingsWindowController()
        controller.setContent(Text("Appearance regression marker"))
        controller.updateAppearance(.dark)
        controller.open()
        defer { controller.close() }
        let window = try XCTUnwrap(controller.window)
        XCTAssertEqual(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .darkAqua)
        XCTAssertTrue(window.isOpaque)
        XCTAssertGreaterThanOrEqual(window.contentLayoutRect.width, 660)
        XCTAssertGreaterThanOrEqual(window.contentLayoutRect.height, 440)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertTrue(window.contentViewController is NSHostingController<AnyView>)
        controller.updateAppearance(.light)
        XCTAssertEqual(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .aqua)
    }

    @MainActor func testQuickEditorGetsKeyboardFocusAfterWindowAttachment() async throws {
        _ = NSApplication.shared
        let controller = SettingsWindowController()
        controller.setContent(MonospacedTextEditor(text: .constant("initial content"), focusOnAppear: true))
        controller.open()
        defer { controller.close() }
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(controller.window?.firstResponder is CommandTextView)
    }

    @MainActor func testWidgetStartsInsideVisibleScreen() async throws {
        _ = NSApplication.shared
        let controller = WidgetWindowController()
        controller.setContent(Text("test widget"))
        controller.show()
        defer { controller.hide() }
        let window = try XCTUnwrap(controller.window)
        let screen = try XCTUnwrap(window.screen)
        XCTAssertTrue(screen.visibleFrame.contains(window.frame))
    }

    func testUpdateVersionAndReleaseAssetSelection() {
        XCTAssertFalse(UpdateController.isNewer("1.6.6", than: "1.6.7"))
        XCTAssertFalse(UpdateController.isNewer("1.6.7", than: "1.6.7"))
        XCTAssertTrue(UpdateController.isNewer("1.10.0", than: "1.9.9"))
        XCTAssertFalse(UpdateController.isNewer("1.7.0-beta", than: "1.6.7"))
        let release: [String: Any] = ["assets": [
            ["name": "Stash-1.7.0-x64.zip", "browser_download_url": "https://github.com/o/r/releases/download/v1.7.0/x64.zip"],
            ["name": "Stash-1.7.0-arm64-mac.zip", "browser_download_url": "https://github.com/o/r/releases/download/v1.7.0/arm64.zip"]]]
        XCTAssertTrue(UpdateController.releaseAsset(release, architecture: "arm64")!.path.hasSuffix("arm64.zip"))
        XCTAssertNil(UpdateController.releaseAsset([:], architecture: "arm64"))
    }
}
