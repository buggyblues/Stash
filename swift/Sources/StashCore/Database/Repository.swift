import Foundation

/// Options accepted by `getItems`.
public struct GetItemsOptions: Equatable, Sendable {
    public var limit: Int
    public var offset: Int
    public var contentType: String?
    public var favoritesOnly: Bool
    public var leftFilter: LeftFilter?
    public var sourceApp: String?
    public var sortBy: SortBy
    public var searchQuery: String?
    public var includeContent: Bool

    public init(
        limit: Int = 50,
        offset: Int = 0,
        contentType: String? = nil,
        favoritesOnly: Bool = false,
        leftFilter: LeftFilter? = nil,
        sourceApp: String? = nil,
        sortBy: SortBy = .recent,
        includeContent: Bool = true,
        searchQuery: String? = nil
    ) {
        self.limit = limit
        self.offset = offset
        self.contentType = contentType
        self.favoritesOnly = favoritesOnly
        self.leftFilter = leftFilter
        self.sourceApp = sourceApp
        self.sortBy = sortBy
        self.includeContent = includeContent
        self.searchQuery = searchQuery
    }
}

/// Options accepted by `getContentTypeCounts`.
public struct ContentTypeCountsOptions: Equatable, Sendable {
    public var leftFilter: LeftFilter?
    public var sourceApp: String?

    public init(leftFilter: LeftFilter? = nil, sourceApp: String? = nil) {
        self.leftFilter = leftFilter
        self.sourceApp = sourceApp
    }
}

/// Aggregate tag statistics shown in the settings window.
public struct TagStats: Equatable, Sendable {
    public var total: Int
    public var singleUse: Int

    public init(total: Int, singleUse: Int) {
        self.total = total
        self.singleUse = singleUse
    }
}

/// All database access for clipboard items, tags, templates and categories.
///
/// Mirrors the query surface of the previous `database/repository.ts` module
/// so behaviour (including ordering and filtering rules) is unchanged.
public final class Repository {
    private let db: SQLiteConnection
    private let encryptor: ContentEncryptor

    public init(db: SQLiteConnection, encryptor: ContentEncryptor = ContentEncryptor()) {
        self.db = db
        self.encryptor = encryptor
    }

    public var connection: SQLiteConnection { db }

    // MARK: - Clipboard items

    public func insertItem(_ item: ClipboardItem) throws {
        let content = encryptor.isKeySet
            ? (encryptor.encryptContent(item.content) ?? item.content)
            : item.content
        try db.execute(
            """
            INSERT INTO clipboard_items (id, content, content_type, content_hash, preview, metadata,
              is_favorite, is_pinned, source_app, tags, title, category_id, created_at, updated_at, use_count)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(item.id),
                .text(content),
                .text(item.contentType),
                .text(item.contentHash),
                .optionalText(item.preview),
                .optionalText(item.metadata),
                .bool(item.isFavorite),
                .bool(item.isPinned),
                .optionalText(item.sourceApp),
                .optionalText(item.tags),
                .optionalText(item.title),
                .optionalText(item.categoryId),
                .int(item.createdAt),
                .int(item.updatedAt),
                .int(Int64(item.useCount))
            ]
        )
    }

    public func updateItem(_ item: ClipboardItem) throws {
        let content = encryptor.isKeySet
            ? (encryptor.encryptContent(item.content) ?? item.content) : item.content
        try db.execute("""
        UPDATE clipboard_items SET content = ?, content_type = ?, content_hash = ?, preview = ?, metadata = ?,
          is_favorite = ?, is_pinned = ?, source_app = ?, tags = ?, title = ?, category_id = ?,
          created_at = ?, updated_at = ?, use_count = ? WHERE id = ?
        """, [.text(content), .text(item.contentType), .text(item.contentHash), .optionalText(item.preview),
              .optionalText(item.metadata), .bool(item.isFavorite), .bool(item.isPinned), .optionalText(item.sourceApp),
              .optionalText(item.tags), .optionalText(item.title), .optionalText(item.categoryId),
              .int(item.createdAt), .int(item.updatedAt), .int(Int64(item.useCount)), .text(item.id)])
    }

    public func getItems(options: GetItemsOptions = GetItemsOptions()) throws -> [ClipboardItem] {
        let resolvedLeftFilter = options.leftFilter
            ?? (options.favoritesOnly ? LeftFilter.starred : LeftFilter.all)

        var conditions: [String] = []
        var params: [SQLValue] = []
        var fromClause = "FROM clipboard_items ci"

        switch resolvedLeftFilter {
        case .all:
            break
        case .starred:
            conditions.append("ci.is_favorite = 1")
        case let .tag(slug):
            // A multi line string literal drops its first line break, so the
            // separator is added explicitly.
            fromClause += "\nJOIN clipboard_item_tags cit ON cit.item_id = ci.id"
                + "\nJOIN tags t ON t.id = cit.tag_id AND t.slug = ?"
            // The join appears before the WHERE clause, so its parameter comes first.
            params.insert(.text(slug), at: 0)
        }

        if let contentType = options.contentType {
            conditions.append("ci.content_type = ?")
            params.append(.text(contentType))
        }

        if let sourceApp = options.sourceApp {
            conditions.append("CASE WHEN json_valid(ci.source_app) THEN json_extract(ci.source_app, '$.bundleId') END = ?")
            params.append(.text(sourceApp))
        }

        if let search = options.searchQuery, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            conditions.append("(ci.content LIKE ? OR ci.preview LIKE ? OR ci.title LIKE ?)")
            params.append(contentsOf: Array(repeating: .text("%\(search)%"), count: 3))
        }

        let columns = options.includeContent ? "ci.*" : Self.itemSummaryColumns
        var query = """
        SELECT \(columns),
          (SELECT GROUP_CONCAT(t2.slug, ',')
           FROM clipboard_item_tags cit2
           JOIN tags t2 ON t2.id = cit2.tag_id
           WHERE cit2.item_id = ci.id) AS tag_slugs
        \(fromClause)
        """
        if !conditions.isEmpty {
            query += " WHERE " + conditions.joined(separator: " AND ")
        }
        let orderBy = options.sortBy == .usage
            ? "ci.is_pinned DESC, ci.use_count DESC, ci.updated_at DESC"
            : "ci.is_pinned DESC, ci.updated_at DESC"
        query += " ORDER BY \(orderBy) LIMIT ? OFFSET ?"
        params.append(.int(Int64(options.limit)))
        params.append(.int(Int64(options.offset)))

        let rows = try db.query(query, params)
        return rows.map { maybeDecrypt(item(from: $0)) }
    }

    public func getItemById(_ id: String) throws -> ClipboardItem? {
        guard let row = try db.query("SELECT * FROM clipboard_items WHERE id = ?", [.text(id)]).first else {
            return nil
        }
        return maybeDecrypt(item(from: row))
    }

    public func getItemContent(_ id: String) throws -> (content: String, contentType: String, metadata: String?)? {
        guard let item = try getItemById(id) else { return nil }
        return (item.content, item.contentType, item.metadata)
    }

    public func getItemByHash(_ hash: String) throws -> ClipboardItem? {
        guard let row = try db.query("SELECT * FROM clipboard_items WHERE content_hash = ?", [.text(hash)]).first else {
            return nil
        }
        return maybeDecrypt(item(from: row))
    }

    public func touchItem(_ id: String) throws {
        try db.execute(
            "UPDATE clipboard_items SET updated_at = ? WHERE id = ?",
            [.int(Self.now()), .text(id)]
        )
    }

    public func incrementUseCount(_ id: String) throws {
        try db.execute(
            "UPDATE clipboard_items SET use_count = COALESCE(use_count, 0) + 1, updated_at = ? WHERE id = ?",
            [.int(Self.now()), .text(id)]
        )
    }

    public func deleteItem(_ id: String) throws {
        try db.execute("DELETE FROM clipboard_items WHERE id = ?", [.text(id)])
    }

    public func getStarredCount() throws -> Int {
        try db.scalarInt("SELECT COUNT(*) as c FROM clipboard_items WHERE is_favorite = 1")
    }

    public func toggleFavorite(_ id: String) throws {
        // Items carrying tags are managed through the tag system and cannot be starred.
        let tagged = try db.scalarInt(
            "SELECT COUNT(*) as c FROM clipboard_item_tags WHERE item_id = ?",
            [.text(id)]
        )
        if tagged > 0 { return }
        try db.execute(
            "UPDATE clipboard_items SET is_favorite = CASE WHEN is_favorite = 0 THEN 1 ELSE 0 END, updated_at = ? WHERE id = ?",
            [.int(Self.now()), .text(id)]
        )
    }

    public func togglePin(_ id: String) throws {
        try db.execute(
            "UPDATE clipboard_items SET is_pinned = CASE WHEN is_pinned = 0 THEN 1 ELSE 0 END, updated_at = ? WHERE id = ?",
            [.int(Self.now()), .text(id)]
        )
    }

    public func searchItems(_ query: String) throws -> [ClipboardItem] {
        try getItems(options: GetItemsOptions(includeContent: false, searchQuery: query))
    }

    public func updateItemTitle(_ id: String, title: String?) throws {
        try db.execute(
            "UPDATE clipboard_items SET title = ?, updated_at = ? WHERE id = ?",
            [.optionalText(title), .int(Self.now()), .text(id)]
        )
    }

    public func clearAll() throws {
        try db.execute("DELETE FROM clipboard_items WHERE is_favorite = 0 AND is_pinned = 0")
    }

    public func getItemCount() throws -> Int {
        try db.scalarInt("SELECT COUNT(*) as count FROM clipboard_items")
    }

    // MARK: - Templates

    public func getTemplates() throws -> [Template] {
        try db.query("SELECT * FROM templates ORDER BY sort_order ASC").map { row in
            Template(
                id: row.string("id") ?? "",
                name: row.string("name") ?? "",
                content: row.string("content") ?? "",
                categoryId: row.string("category_id"),
                sortOrder: row.int("sort_order") ?? 0,
                createdAt: row.int64("created_at") ?? 0,
                updatedAt: row.int64("updated_at") ?? 0
            )
        }
    }

    public func createTemplate(id: String, name: String, content: String, categoryId: String?) throws {
        let now = Self.now()
        try db.execute(
            """
            INSERT INTO templates (id, name, content, category_id, sort_order, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(id), .text(name), .text(content),
                .optionalText(categoryId?.isEmpty == true ? nil : categoryId),
                .int(0), .int(now), .int(now)
            ]
        )
    }

    public func updateTemplate(id: String, name: String, content: String) throws {
        try db.execute(
            "UPDATE templates SET name = ?, content = ?, updated_at = ? WHERE id = ?",
            [.text(name), .text(content), .int(Self.now()), .text(id)]
        )
    }

    public func deleteTemplate(_ id: String) throws {
        try db.execute("DELETE FROM templates WHERE id = ?", [.text(id)])
    }

    // MARK: - Categories

    public func getCategories() throws -> [Category] {
        try db.query("SELECT * FROM categories ORDER BY sort_order ASC").map { row in
            Category(
                id: row.string("id") ?? "",
                name: row.string("name") ?? "",
                color: row.string("color"),
                sortOrder: row.int("sort_order") ?? 0,
                createdAt: row.int64("created_at") ?? 0
            )
        }
    }

    public func createCategory(id: String, name: String, color: String?) throws {
        try db.execute(
            "INSERT INTO categories (id, name, color, sort_order, created_at) VALUES (?, ?, ?, ?, ?)",
            [.text(id), .text(name), .optionalText(color), .int(0), .int(Self.now())]
        )
    }

    public func deleteCategory(_ id: String) throws {
        try db.execute("UPDATE clipboard_items SET category_id = NULL WHERE category_id = ?", [.text(id)])
        try db.execute("DELETE FROM categories WHERE id = ?", [.text(id)])
    }

    public func updateItemCategory(itemId: String, categoryId: String?) throws {
        try db.execute(
            "UPDATE clipboard_items SET category_id = ?, updated_at = ? WHERE id = ?",
            [.optionalText(categoryId), .int(Self.now()), .text(itemId)]
        )
    }

    // MARK: - Cleanup

    public func autoCleanup(maxItems: Int = 2000) throws {
        let count = try getItemCount()
        let deleteCount = MaxItems.autoCleanupDeleteCount(count: count, maxItems: maxItems)
        guard deleteCount > 0 else { return }

        try db.execute(
            """
            DELETE FROM clipboard_items
            WHERE id IN (
              SELECT id FROM clipboard_items
              WHERE is_favorite = 0 AND is_pinned = 0
                AND id NOT IN (SELECT DISTINCT item_id FROM clipboard_item_tags)
              ORDER BY updated_at ASC
              LIMIT ?
            )
            """,
            [.int(Int64(deleteCount))]
        )
    }

    public func cleanupByRetention(days: Int) throws {
        guard days > 0 else { return }
        let cutoff = Self.now() - Int64(days) * 24 * 60 * 60 * 1000
        try db.execute(
            """
            DELETE FROM clipboard_items
            WHERE is_favorite = 0 AND is_pinned = 0
              AND id NOT IN (SELECT DISTINCT item_id FROM clipboard_item_tags)
              AND updated_at < ?
            """,
            [.int(cutoff)]
        )
    }

    // MARK: - Tags

    public func listTagsWithCounts() throws -> [TagWithCount] {
        try db.query("""
        SELECT t.*, COUNT(cit.item_id) as count
        FROM tags t
        LEFT JOIN clipboard_item_tags cit ON cit.tag_id = t.id
        GROUP BY t.id
        ORDER BY t.last_used_at DESC, t.created_at DESC
        """).map { row in
            TagWithCount(
                tag: Tag(
                    id: row.string("id") ?? "",
                    slug: row.string("slug") ?? "",
                    name: row.string("name") ?? "",
                    createdAt: row.int64("created_at") ?? 0,
                    updatedAt: row.int64("updated_at") ?? 0,
                    lastUsedAt: row.int64("last_used_at")
                ),
                count: row.int("count") ?? 0
            )
        }
    }

    public func applyTags(itemId: String, slugs: [String]) throws {
        guard !slugs.isEmpty else { return }
        let now = Self.now()

        try db.transaction {
            for rawName in slugs {
                let slug = Slug.make(rawName)
                guard !slug.isEmpty else { continue }

                let existing = try db.query("SELECT id FROM tags WHERE slug = ?", [.text(slug)])
                let tagId: String
                if let found = existing.first, let foundId = found.string("id") {
                    tagId = foundId
                    try db.execute(
                        "UPDATE tags SET last_used_at = ?, updated_at = ? WHERE id = ?",
                        [.int(now), .int(now), .text(tagId)]
                    )
                } else {
                    tagId = "tag_\(now)_\(String(UUID().uuidString.prefix(8)))"
                    try db.execute(
                        """
                        INSERT OR IGNORE INTO tags (id, slug, name, created_at, updated_at, last_used_at)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """,
                        [.text(tagId), .text(slug), .text(rawName), .int(now), .int(now), .int(now)]
                    )
                }
                try db.execute(
                    "INSERT OR IGNORE INTO clipboard_item_tags (item_id, tag_id, created_at) VALUES (?, ?, ?)",
                    [.text(itemId), .text(tagId), .int(now)]
                )
            }
            // Tagging an item removes it from the starred collection.
            try db.execute(
                "UPDATE clipboard_items SET is_favorite = 0, updated_at = ? WHERE id = ?",
                [.int(now), .text(itemId)]
            )
        }
    }

    public func removeTag(itemId: String, slug: String) throws {
        try db.execute(
            """
            DELETE FROM clipboard_item_tags
            WHERE item_id = ?
              AND tag_id = (SELECT id FROM tags WHERE slug = ?)
            """,
            [.text(itemId), .text(slug)]
        )
    }

    public func getItemTagSlugs(_ itemId: String) throws -> [String] {
        try db.query(
            """
            SELECT t.slug FROM tags t
            JOIN clipboard_item_tags cit ON cit.tag_id = t.id
            WHERE cit.item_id = ?
            """,
            [.text(itemId)]
        ).compactMap { $0.string("slug") }
    }

    public func renameTag(slug: String, nextName: String) throws {
        let nextSlug = Slug.make(nextName)
        guard !nextSlug.isEmpty else { return }
        try db.execute(
            "UPDATE tags SET name = ?, slug = ?, updated_at = ? WHERE slug = ?",
            [.text(nextName), .text(nextSlug), .int(Self.now()), .text(slug)]
        )
    }

    public func deleteTag(slug: String) throws {
        try db.execute("DELETE FROM tags WHERE slug = ?", [.text(slug)])
    }

    public func mergeTag(sourceSlug: String, targetSlug: String) throws {
        guard sourceSlug != targetSlug else { return }
        let now = Self.now()
        try db.transaction {
            guard let source = try db.query("SELECT id FROM tags WHERE slug = ?", [.text(sourceSlug)]).first,
                  let sourceId = source.string("id"),
                  let target = try db.query("SELECT id FROM tags WHERE slug = ?", [.text(targetSlug)]).first,
                  let targetId = target.string("id")
            else { return }

            let items = try db.query(
                "SELECT item_id FROM clipboard_item_tags WHERE tag_id = ?",
                [.text(sourceId)]
            )
            for row in items {
                guard let itemId = row.string("item_id") else { continue }
                try db.execute(
                    "INSERT OR IGNORE INTO clipboard_item_tags (item_id, tag_id, created_at) VALUES (?, ?, ?)",
                    [.text(itemId), .text(targetId), .int(now)]
                )
            }
            try db.execute("DELETE FROM tags WHERE id = ?", [.text(sourceId)])
            try db.execute(
                "UPDATE tags SET last_used_at = ?, updated_at = ? WHERE id = ?",
                [.int(now), .int(now), .text(targetId)]
            )
        }
    }

    public func getTagStats() throws -> TagStats {
        let total = try db.scalarInt("SELECT COUNT(*) as c FROM tags")
        let singleUse = try db.scalarInt("""
        SELECT COUNT(*) as c FROM (
          SELECT tag_id FROM clipboard_item_tags GROUP BY tag_id HAVING COUNT(*) = 1
        )
        """)
        return TagStats(total: total, singleUse: singleUse)
    }

    public func getSimilarTags(name: String) throws -> [Tag] {
        let slug = Slug.make(name)
        guard !slug.isEmpty else { return [] }
        let pattern = "%\(slug.replacingOccurrences(of: "-", with: "%"))%"
        return try db.query("SELECT * FROM tags WHERE slug LIKE ? LIMIT 5", [.text(pattern)]).map { row in
            Tag(
                id: row.string("id") ?? "",
                slug: row.string("slug") ?? "",
                name: row.string("name") ?? "",
                createdAt: row.int64("created_at") ?? 0,
                updatedAt: row.int64("updated_at") ?? 0,
                lastUsedAt: row.int64("last_used_at")
            )
        }
    }

    // MARK: - Source apps & type counts

    public func getContentTypeCounts(options: ContentTypeCountsOptions = ContentTypeCountsOptions()) throws -> [String: Int] {
        var conditions: [String] = []
        var params: [SQLValue] = []
        var fromClause = "FROM clipboard_items ci"

        switch options.leftFilter ?? .all {
        case .all:
            break
        case .starred:
            conditions.append("ci.is_favorite = 1")
        case let .tag(slug):
            fromClause += "\nJOIN clipboard_item_tags cit ON cit.item_id = ci.id"
                + "\nJOIN tags t ON t.id = cit.tag_id AND t.slug = ?"
            params.append(.text(slug))
        }

        if let sourceApp = options.sourceApp {
            conditions.append("CASE WHEN json_valid(ci.source_app) THEN json_extract(ci.source_app, '$.bundleId') END = ?")
            params.append(.text(sourceApp))
        }

        var query = "SELECT ci.content_type, COUNT(*) as count \(fromClause)"
        if !conditions.isEmpty {
            query += " WHERE " + conditions.joined(separator: " AND ")
        }
        query += " GROUP BY ci.content_type"

        var result: [String: Int] = [:]
        for row in try db.query(query, params) {
            guard let type = row.string("content_type") else { continue }
            result[type] = row.int("count") ?? 0
        }
        return result
    }

    public func getSourceApps() throws -> [SourceApp] {
        let rows = try db.query("""
        SELECT source_app, COUNT(*) as count
        FROM clipboard_items
        WHERE source_app IS NOT NULL
        GROUP BY source_app
        ORDER BY count DESC
        """)
        var grouped: [String: SourceApp] = [:]
        for row in rows {
            guard let raw = row.string("source_app") else { continue }
            var app = SourceApp.decode(raw) ?? SourceApp(name: raw, bundleId: "")
            app.count = row.int("count") ?? 0
            if let existing = grouped[app.id] { app.count += existing.count }
            grouped[app.id] = app
        }
        return grouped.values.sorted {
            $0.count == $1.count ? $0.id < $1.id : $0.count > $1.count
        }
    }

    // MARK: - Internals

    /// The panel only needs metadata and a short preview to render its list.
    /// The potentially very large content column is loaded on demand instead.
    private static let itemSummaryColumns = """
    ci.id,
    '' AS content,
    ci.content_type,
    ci.content_hash,
    ci.preview,
    ci.metadata,
    ci.is_favorite,
    ci.is_pinned,
    ci.source_app,
    ci.tags,
    ci.title,
    ci.category_id,
    ci.created_at,
    ci.updated_at,
    ci.use_count
    """

    private func item(from row: SQLRow) -> ClipboardItem {
        ClipboardItem(
            id: row.string("id") ?? "",
            content: row.string("content") ?? "",
            contentType: row.string("content_type") ?? ContentType.text.rawValue,
            contentHash: row.string("content_hash") ?? "",
            preview: row.string("preview"),
            metadata: row.string("metadata"),
            isFavorite: row.bool("is_favorite"),
            isPinned: row.bool("is_pinned"),
            sourceApp: row.string("source_app"),
            tags: row.string("tags"),
            title: row.string("title"),
            categoryId: row.string("category_id"),
            createdAt: row.int64("created_at") ?? 0,
            updatedAt: row.int64("updated_at") ?? 0,
            useCount: row.int("use_count") ?? 0,
            tagSlugs: row.string("tag_slugs")
        )
    }

    /// Decrypts the content column when the database is encrypted.
    private func maybeDecrypt(_ item: ClipboardItem) -> ClipboardItem {
        guard encryptor.isKeySet else { return item }
        guard let decrypted = encryptor.decryptContent(item.content) else { return item }
        var copy = item
        copy.content = decrypted
        return copy
    }

    private static func now() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
