import Foundation

/// Creates the database schema and keeps it in sync with the previous
/// Electron build (same table layout, same indexes, same migrations).
public enum Schema {
    public static func createTables(in db: SQLiteConnection) throws {
        try db.executeScript("""
        CREATE TABLE IF NOT EXISTS clipboard_items (
          id            TEXT PRIMARY KEY,
          content       TEXT NOT NULL,
          content_type  TEXT NOT NULL,
          content_hash  TEXT UNIQUE NOT NULL,
          preview       TEXT,
          metadata      TEXT,
          is_favorite   INTEGER DEFAULT 0,
          is_pinned     INTEGER DEFAULT 0,
          source_app    TEXT,
          tags          TEXT,
          category_id   TEXT,
          created_at    INTEGER NOT NULL,
          updated_at    INTEGER NOT NULL,
          use_count     INTEGER DEFAULT 0
        );

        CREATE INDEX IF NOT EXISTS idx_items_created ON clipboard_items(created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_items_type ON clipboard_items(content_type);
        CREATE INDEX IF NOT EXISTS idx_items_favorite ON clipboard_items(is_favorite);
        CREATE INDEX IF NOT EXISTS idx_items_hash ON clipboard_items(content_hash);

        CREATE TABLE IF NOT EXISTS categories (
          id          TEXT PRIMARY KEY,
          name        TEXT NOT NULL,
          color       TEXT,
          sort_order  INTEGER DEFAULT 0,
          created_at  INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS templates (
          id          TEXT PRIMARY KEY,
          name        TEXT NOT NULL,
          content     TEXT NOT NULL,
          category_id TEXT,
          sort_order  INTEGER DEFAULT 0,
          created_at  INTEGER NOT NULL,
          updated_at  INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS tags (
          id           TEXT PRIMARY KEY,
          slug         TEXT NOT NULL UNIQUE,
          name         TEXT NOT NULL,
          created_at   INTEGER NOT NULL,
          updated_at   INTEGER NOT NULL,
          last_used_at INTEGER
        );

        CREATE INDEX IF NOT EXISTS idx_tags_slug ON tags(slug);

        CREATE TABLE IF NOT EXISTS clipboard_item_tags (
          item_id    TEXT NOT NULL,
          tag_id     TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (item_id, tag_id),
          FOREIGN KEY (item_id) REFERENCES clipboard_items(id) ON DELETE CASCADE,
          FOREIGN KEY (tag_id)  REFERENCES tags(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_item_tags_item ON clipboard_item_tags(item_id);
        CREATE INDEX IF NOT EXISTS idx_item_tags_tag  ON clipboard_item_tags(tag_id);
        """)

        // Additive column migrations for databases created by older versions.
        let columns = try db.query("PRAGMA table_info(clipboard_items)")
        let names = Set(columns.compactMap { $0.string("name") })
        if !names.contains("title") {
            try db.execute("ALTER TABLE clipboard_items ADD COLUMN title TEXT")
        }
        if !names.contains("use_count") {
            try db.execute("ALTER TABLE clipboard_items ADD COLUMN use_count INTEGER DEFAULT 0")
        }

        // Keep the common ordered queries on the small metadata indexes instead of
        // sorting rows that contain potentially megabytes of clipboard content.
        try db.executeScript("""
        CREATE INDEX IF NOT EXISTS idx_items_pinned_updated
          ON clipboard_items(is_pinned DESC, updated_at DESC);
        CREATE INDEX IF NOT EXISTS idx_items_pinned_usage_updated
          ON clipboard_items(is_pinned DESC, use_count DESC, updated_at DESC);
        CREATE INDEX IF NOT EXISTS idx_items_type_pinned_updated
          ON clipboard_items(content_type, is_pinned DESC, updated_at DESC);
        CREATE INDEX IF NOT EXISTS idx_items_favorite_order
          ON clipboard_items(is_favorite, is_pinned DESC, updated_at DESC);
        """)

        try migrateLegacyTags(in: db)
    }

    /// Moves the legacy `clipboard_items.tags` JSON column into the tag tables.
    private static func migrateLegacyTags(in db: SQLiteConnection) throws {
        let items = try db.query(
            "SELECT id, tags FROM clipboard_items WHERE tags IS NOT NULL AND tags != ''"
        )
        guard !items.isEmpty else { return }

        try db.transaction {
            for row in items {
                guard let id = row.string("id"), let raw = row.string("tags") else { continue }
                var names: [String] = []
                if let data = raw.data(using: .utf8),
                   let object = try? JSONSerialization.jsonObject(with: data) {
                    if let list = object as? [String] {
                        names = list
                    } else {
                        names = [String(describing: object)]
                    }
                } else {
                    names = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                }

                for name in names where !name.isEmpty {
                    let slug = Slug.make(name)
                    guard !slug.isEmpty else { continue }
                    let now = Int64(Date().timeIntervalSince1970 * 1000)
                    let existing = try db.query("SELECT id FROM tags WHERE slug = ?", [.text(slug)])
                    let tagId: String
                    if let found = existing.first, let foundId = found.string("id") {
                        tagId = foundId
                    } else {
                        tagId = "tag_\(now)_\(String(UUID().uuidString.prefix(8)))"
                        try db.execute(
                            "INSERT OR IGNORE INTO tags (id, slug, name, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
                            [.text(tagId), .text(slug), .text(name), .int(now), .int(now)]
                        )
                    }
                    try db.execute(
                        "INSERT OR IGNORE INTO clipboard_item_tags (item_id, tag_id, created_at) VALUES (?, ?, ?)",
                        [.text(id), .text(tagId), .int(now)]
                    )
                }
                // The join table is now authoritative. Clear the legacy payload
                // so a removed or renamed tag cannot reappear on the next launch.
                try db.execute("UPDATE clipboard_items SET tags = NULL WHERE id = ?", [.text(id)])
            }
        }
    }
}

/// Converts a human readable tag name into the slug used as its identity.
public enum Slug {
    public static func make(_ name: String) -> String {
        var slug = name.lowercased()
        // Every run of whitespace becomes a single dash.
        slug = slug.replacingOccurrences(
            of: "\\s+",
            with: "-",
            options: .regularExpression
        )
        // Trim leading/trailing dashes.
        while slug.hasPrefix("-") { slug.removeFirst() }
        while slug.hasSuffix("-") { slug.removeLast() }
        // Collapse repeated dashes.
        while slug.contains("--") { slug = slug.replacingOccurrences(of: "--", with: "-") }
        return slug
    }
}
