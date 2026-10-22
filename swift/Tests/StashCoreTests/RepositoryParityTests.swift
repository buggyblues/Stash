import XCTest
@testable import StashCore

/// Locks the behaviour of the storage layer to the semantics of the previous
/// Electron build.
final class RepositoryParityTests: XCTestCase {
    private var database: SQLiteConnection!
    private var repository: Repository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let path = NSTemporaryDirectory() + "stash-parity-\(UUID().uuidString).db"
        database = try SQLiteConnection(path: path)
        try Schema.createTables(in: database)
        repository = Repository(db: database)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: databasePath)
        try super.tearDownWithError()
    }

    private var databasePath: String { database.path }

    // MARK: - Helpers

    private func makeItem(
        id: String,
        content: String,
        type: String = "text",
        favorite: Bool = false,
        pinned: Bool = false,
        sourceApp: String? = nil,
        title: String? = nil,
        created: Int64 = 1_700_000_000_000,
        updated: Int64? = nil,
        useCount: Int = 0
    ) -> ClipboardItem {
        ClipboardItem(
            id: id,
            content: content,
            contentType: type,
            contentHash: "hash-\(id)",
            preview: String(content.prefix(200)),
            metadata: nil,
            isFavorite: favorite,
            isPinned: pinned,
            sourceApp: sourceApp,
            tags: nil,
            title: title,
            categoryId: nil,
            createdAt: created,
            updatedAt: updated ?? created,
            useCount: useCount
        )
    }

    // MARK: - Ordering

    func testPinnedItemsComeFirstThenByUpdatedAt() throws {
        try repository.insertItem(makeItem(id: "a", content: "a", updated: 300))
        try repository.insertItem(makeItem(id: "b", content: "b", updated: 200))
        try repository.insertItem(makeItem(id: "p", content: "p", pinned: true, updated: 100))

        let items = try repository.getItems(options: GetItemsOptions())
        XCTAssertEqual(items.map(\.id), ["p", "a", "b"])
    }

    func testUsageSortPrefersMostUsed() throws {
        try repository.insertItem(makeItem(id: "a", content: "a", updated: 300, useCount: 1))
        try repository.insertItem(makeItem(id: "b", content: "b", updated: 200, useCount: 9))

        let items = try repository.getItems(options: GetItemsOptions(sortBy: .usage))
        XCTAssertEqual(items.map(\.id), ["b", "a"])
    }

    // MARK: - Favourite / tag interplay

    func testTaggingAnItemClearsTheStar() throws {
        try repository.insertItem(makeItem(id: "a", content: "a", favorite: true))
        try repository.applyTags(itemId: "a", slugs: ["Work"])
        try repository.applyTags(itemId: "a", slugs: ["Work"])

        let item = try XCTUnwrap(try repository.getItemById("a"))
        XCTAssertFalse(item.isFavorite)
        XCTAssertEqual(try repository.getItemTagSlugs("a"), ["work"])
    }

    func testStarringATaggedItemIsIgnored() throws {
        try repository.insertItem(makeItem(id: "a", content: "a"))
        try repository.applyTags(itemId: "a", slugs: ["Work"])

        try repository.toggleFavorite("a")
        let item = try XCTUnwrap(try repository.getItemById("a"))
        XCTAssertFalse(item.isFavorite)
    }

    func testStarringAnUntaggedItemWorks() throws {
        try repository.insertItem(makeItem(id: "a", content: "a"))
        try repository.toggleFavorite("a")
        let item = try XCTUnwrap(try repository.getItemById("a"))
        XCTAssertTrue(item.isFavorite)
    }

    // MARK: - Clearing

    func testClearAllKeepsFavouritesAndPinnedItems() throws {
        try repository.insertItem(makeItem(id: "plain", content: "plain"))
        try repository.insertItem(makeItem(id: "star", content: "star", favorite: true))
        try repository.insertItem(makeItem(id: "pin", content: "pin", pinned: true))

        try repository.clearAll()
        let remaining = Set(try repository.getItems(options: GetItemsOptions()).map(\.id))
        XCTAssertEqual(remaining, ["star", "pin"])
    }

    func testAutoCleanupRemovesTheOldestUntaggedItems() throws {
        // The limit is normalised to at least 500, so the fixture uses 502
        // regular items plus one favourite.
        for index in 0..<502 {
            try repository.insertItem(makeItem(id: "item\(index)", content: "c\(index)", updated: Int64(index + 1)))
        }
        try repository.insertItem(makeItem(id: "star", content: "star", favorite: true, updated: 0))

        try repository.autoCleanup(maxItems: 500)
        XCTAssertEqual(try repository.getItemCount(), 500)

        let remaining = Set(try repository.getItems(options: GetItemsOptions(limit: 1000)).map(\.id))
        XCTAssertTrue(remaining.contains("star"))
        XCTAssertFalse(remaining.contains("item0"))
        XCTAssertFalse(remaining.contains("item1"))
        XCTAssertFalse(remaining.contains("item2"))
        XCTAssertTrue(remaining.contains("item501"))
    }

    func testAutoCleanupKeepsTaggedItems() throws {
        for index in 0..<502 {
            try repository.insertItem(makeItem(id: "item\(index)", content: "c\(index)", updated: Int64(index + 1)))
        }
        try repository.applyTags(itemId: "item0", slugs: ["Keep"])

        try repository.autoCleanup(maxItems: 500)
        let remaining = Set(try repository.getItems(options: GetItemsOptions(limit: 1000)).map(\.id))
        XCTAssertTrue(remaining.contains("item0"))
        XCTAssertFalse(remaining.contains("item1"))
    }

    func testUnlimitedMaxItemsKeepsEverything() throws {
        try repository.insertItem(makeItem(id: "a", content: "a"))
        try repository.autoCleanup(maxItems: 0)
        XCTAssertEqual(try repository.getItemCount(), 1)
    }

    // MARK: - Filters

    func testSourceAppFilterMatchesTheStoredJson() throws {
        let source = SourceApp(name: "Chrome", bundleId: "com.google.Chrome").encoded()
        try repository.insertItem(makeItem(id: "a", content: "a", sourceApp: source))
        try repository.insertItem(makeItem(id: "b", content: "b"))

        let items = try repository.getItems(options: GetItemsOptions(sourceApp: "com.google.Chrome"))
        XCTAssertEqual(items.map(\.id), ["a"])
    }

    func testTagFilterJoinsThroughTheTagTable() throws {
        try repository.insertItem(makeItem(id: "a", content: "a"))
        try repository.insertItem(makeItem(id: "b", content: "b"))
        try repository.applyTags(itemId: "a", slugs: ["Work"])

        let items = try repository.getItems(options: GetItemsOptions(leftFilter: .tag(slug: "work")))
        XCTAssertEqual(items.map(\.id), ["a"])
    }

    func testStarredFilterUsesTheFavouriteFlag() throws {
        try repository.insertItem(makeItem(id: "a", content: "a"))
        try repository.insertItem(makeItem(id: "b", content: "b", favorite: true))

        let items = try repository.getItems(options: GetItemsOptions(leftFilter: .starred))
        XCTAssertEqual(items.map(\.id), ["b"])
    }

    // MARK: - Content types & source apps

    func testContentTypeCountsIgnoreTheTypeFilterButRespectTheLeftFilter() throws {
        try repository.insertItem(makeItem(id: "a", content: "a", type: "text"))
        try repository.insertItem(makeItem(id: "b", content: "b", type: "code", favorite: true))

        let all = try repository.getContentTypeCounts(options: ContentTypeCountsOptions())
        XCTAssertEqual(all["text"], 1)
        XCTAssertEqual(all["code"], 1)

        let starred = try repository.getContentTypeCounts(
            options: ContentTypeCountsOptions(leftFilter: .starred)
        )
        XCTAssertEqual(starred["code"], 1)
        XCTAssertNil(starred["text"])
    }

    func testSourceAppsAreGroupedAndSortedByCount() throws {
        let chrome = SourceApp(name: "Chrome", bundleId: "com.google.Chrome").encoded()
        let notes = SourceApp(name: "Notes", bundleId: "com.apple.Notes").encoded()
        try repository.insertItem(makeItem(id: "a", content: "a", sourceApp: chrome))
        try repository.insertItem(makeItem(id: "b", content: "b", sourceApp: chrome))
        try repository.insertItem(makeItem(id: "c", content: "c", sourceApp: notes))

        let apps = try repository.getSourceApps()
        XCTAssertEqual(apps.first?.bundleId, "com.google.Chrome")
        XCTAssertEqual(apps.first?.count, 2)
        XCTAssertEqual(apps.count, 2)
    }

    // MARK: - Search

    func testSearchMatchesContentPreviewAndTitle() throws {
        try repository.insertItem(makeItem(id: "a", content: "hello world"))
        try repository.insertItem(makeItem(id: "b", content: "other", title: "hello title"))

        let found = try repository.searchItems("hello")
        XCTAssertEqual(Set(found.map(\.id)), ["a", "b"])
    }

    func testSearchIsCaseInsensitiveForAscii() throws {
        try repository.insertItem(makeItem(id: "a", content: "Hello World"))
        let found = try repository.searchItems("hello")
        XCTAssertEqual(found.map(\.id), ["a"])
    }

    // MARK: - Tags

    func testRenamingATagChangesItsSlug() throws {
        try repository.insertItem(makeItem(id: "a", content: "a"))
        try repository.applyTags(itemId: "a", slugs: ["Old Name"])

        try repository.renameTag(slug: "old-name", nextName: "New Name")
        let tags = try repository.listTagsWithCounts()
        XCTAssertEqual(tags.first?.slug, "new-name")
        XCTAssertEqual(tags.first?.name, "New Name")
    }

    func testMergingMovesTheItemsAndRemovesTheSource() throws {
        try repository.insertItem(makeItem(id: "a", content: "a"))
        try repository.insertItem(makeItem(id: "b", content: "b"))
        try repository.applyTags(itemId: "a", slugs: ["Source"])
        try repository.applyTags(itemId: "b", slugs: ["Target"])

        try repository.mergeTag(sourceSlug: "source", targetSlug: "target")

        let tags = try repository.listTagsWithCounts()
        XCTAssertEqual(tags.map(\.slug), ["target"])
        XCTAssertEqual(tags.first?.count, 2)
    }

    func testDeletingATagRemovesItFromTheItems() throws {
        try repository.insertItem(makeItem(id: "a", content: "a"))
        try repository.applyTags(itemId: "a", slugs: ["Gone"])

        try repository.deleteTag(slug: "gone")
        XCTAssertEqual(try repository.getItemTagSlugs("a"), [])
        XCTAssertEqual(try repository.getTagStats().total, 0)
    }

    func testTagStatsCountSingleUseTags() throws {
        try repository.insertItem(makeItem(id: "a", content: "a"))
        try repository.insertItem(makeItem(id: "b", content: "b"))
        try repository.applyTags(itemId: "a", slugs: ["Once"])
        try repository.applyTags(itemId: "a", slugs: ["Twice"])
        try repository.applyTags(itemId: "b", slugs: ["Twice"])

        let stats = try repository.getTagStats()
        XCTAssertEqual(stats.total, 2)
        XCTAssertEqual(stats.singleUse, 1)
    }

    func testSimilarTagsUseTheWildcardPattern() throws {
        try repository.insertItem(makeItem(id: "a", content: "a"))
        try repository.applyTags(itemId: "a", slugs: ["project-plan"])

        let similar = try repository.getSimilarTags(name: "plan")
        XCTAssertEqual(similar.map(\.slug), ["project-plan"])
    }

    // MARK: - Templates & categories

    func testTemplatesAreOrderedAndCanBeRemoved() throws {
        try repository.createTemplate(id: "t1", name: "One", content: "a", categoryId: nil)
        try repository.createTemplate(id: "t2", name: "Two", content: "b", categoryId: nil)

        XCTAssertEqual(try repository.getTemplates().map(\.id), ["t1", "t2"])

        try repository.updateTemplate(id: "t1", name: "One!", content: "c")
        XCTAssertEqual(try repository.getTemplates().first?.name, "One!")

        try repository.deleteTemplate("t2")
        XCTAssertEqual(try repository.getTemplates().count, 1)
    }

    func testDeletingACategoryClearsItFromTheItems() throws {
        try repository.createCategory(id: "c1", name: "Work", color: "#fff")
        try repository.insertItem(makeItem(id: "a", content: "a"))
        try repository.updateItemCategory(itemId: "a", categoryId: "c1")

        try repository.deleteCategory("c1")
        let item = try XCTUnwrap(try repository.getItemById("a"))
        XCTAssertNil(item.categoryId)
    }

    // MARK: - Use count

    func testIncrementingTheUseCountAlsoUpdatesTheTimestamp() throws {
        try repository.insertItem(makeItem(id: "a", content: "a", updated: 100))
        try repository.incrementUseCount("a")

        let item = try XCTUnwrap(try repository.getItemById("a"))
        XCTAssertEqual(item.useCount, 1)
        XCTAssertGreaterThan(item.updatedAt, 100)
    }
}
