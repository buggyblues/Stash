import { getDatabase } from './connection'

export function createTables(): void {
  const db = getDatabase()

  db.exec(`
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

  `)

  // Add title column if missing
  const cols = db.prepare("PRAGMA table_info(clipboard_items)").all() as { name: string }[]
  if (!cols.some((c) => c.name === 'title')) {
    db.exec(`ALTER TABLE clipboard_items ADD COLUMN title TEXT`)
  }
  if (!cols.some((c) => c.name === 'use_count')) {
    db.exec(`ALTER TABLE clipboard_items ADD COLUMN use_count INTEGER DEFAULT 0`)
  }

  // Keep the common ordered queries on the small metadata indexes instead of
  // sorting rows that contain potentially megabytes of clipboard content.
  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_items_pinned_updated
      ON clipboard_items(is_pinned DESC, updated_at DESC);
    CREATE INDEX IF NOT EXISTS idx_items_pinned_usage_updated
      ON clipboard_items(is_pinned DESC, use_count DESC, updated_at DESC);
    CREATE INDEX IF NOT EXISTS idx_items_type_pinned_updated
      ON clipboard_items(content_type, is_pinned DESC, updated_at DESC);
    CREATE INDEX IF NOT EXISTS idx_items_favorite_order
      ON clipboard_items(is_favorite, is_pinned DESC, updated_at DESC);
  `)

  migrateOldTags()

}

function toSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-')
}

function migrateOldTags(): void {
  const db = getDatabase()
  const items = db
    .prepare(`SELECT id, tags FROM clipboard_items WHERE tags IS NOT NULL AND tags != ''`)
    .all() as { id: string; tags: string }[]

  if (items.length === 0) return

  const insertTag = db.prepare(`
    INSERT OR IGNORE INTO tags (id, slug, name, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?)
  `)
  const getTagBySlug = db.prepare(`SELECT id FROM tags WHERE slug = ?`)
  const insertMapping = db.prepare(`
    INSERT OR IGNORE INTO clipboard_item_tags (item_id, tag_id, created_at) VALUES (?, ?, ?)
  `)

  const migrate = db.transaction(() => {
    for (const item of items) {
      let names: string[] = []
      try {
        names = JSON.parse(item.tags)
        if (!Array.isArray(names)) names = [String(names)]
      } catch {
        names = item.tags.split(',').map((s) => s.trim()).filter(Boolean)
      }
      for (const name of names) {
        if (!name) continue
        const slug = toSlug(name)
        if (!slug) continue
        const existing = getTagBySlug.get(slug) as { id: string } | undefined
        let tagId: string
        if (existing) {
          tagId = existing.id
        } else {
          tagId = `tag_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
          insertTag.run(tagId, slug, name, Date.now(), Date.now())
        }
        insertMapping.run(item.id, tagId, Date.now())
      }
    }
  })

  migrate()
}
