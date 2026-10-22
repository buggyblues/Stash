import { getDatabase } from './connection'
import { encryptContent, decryptContent, isKeySet } from '../security/encryption'
import { getAutoCleanupDeleteCount } from '../../shared/max-items'

export interface ClipboardItem {
  id: string
  content: string
  content_type: string
  content_hash: string
  preview: string | null
  metadata: string | null
  is_favorite: number
  is_pinned: number
  source_app: string | null
  tags: string | null
  title: string | null
  category_id: string | null
  created_at: number
  updated_at: number
  use_count: number
  tag_slugs?: string | null
}

export type LeftFilter =
  | { type: 'all' }
  | { type: 'starred' }
  | { type: 'tag'; slug: string }

export interface GetItemsOptions {
  limit?: number
  offset?: number
  contentType?: string
  favoritesOnly?: boolean
  leftFilter?: LeftFilter
  sourceApp?: string
  sortBy?: 'recent' | 'usage'
  includeContent?: boolean
}

export interface Tag {
  id: string
  slug: string
  name: string
  created_at: number
  updated_at: number
  last_used_at: number | null
}

export interface TagWithCount extends Tag {
  count: number
}

function toSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-')
}

export function insertItem(item: ClipboardItem): void {
  const db = getDatabase()
  const content = isKeySet() ? (encryptContent(item.content) || item.content) : item.content
  const stmt = db.prepare(`
    INSERT INTO clipboard_items (id, content, content_type, content_hash, preview, metadata,
      is_favorite, is_pinned, source_app, tags, title, category_id, created_at, updated_at, use_count)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `)
  stmt.run(
    item.id,
    content,
    item.content_type,
    item.content_hash,
    item.preview,
    item.metadata,
    item.is_favorite,
    item.is_pinned,
    item.source_app,
    item.tags,
    item.title ?? null,
    item.category_id,
    item.created_at,
    item.updated_at,
    item.use_count ?? 0
  )
}

function maybeDecryptItem(item: ClipboardItem): ClipboardItem {
  if (!isKeySet()) return item
  try {
    const parsed = JSON.parse(item.content)
    if (parsed.ciphertext && parsed.iv && parsed.tag) {
      const decrypted = decryptContent(item.content)
      if (decrypted) {
        return { ...item, content: decrypted }
      }
    }
  } catch {
    // not encrypted or invalid, return as-is
  }
  return item
}

// The panel only needs metadata and a short preview to render its list. Keep
// the potentially very large content column out of the renderer IPC payload
// and load it by id when an item is actually previewed or edited.
const ITEM_SUMMARY_COLUMNS = `
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
  ci.use_count`

export function getItems(options: GetItemsOptions = {}): ClipboardItem[] {
  const db = getDatabase()
  const {
    limit = 50,
    offset = 0,
    contentType,
    favoritesOnly,
    leftFilter,
    sourceApp,
    sortBy = 'recent',
    includeContent = true
  } = options

  const conditions: string[] = []
  const params: unknown[] = []
  let fromClause = 'FROM clipboard_items ci'

  const resolvedLeftFilter = leftFilter ?? (favoritesOnly ? { type: 'starred' as const } : { type: 'all' as const })

  if (resolvedLeftFilter.type === 'starred') {
    conditions.push('ci.is_favorite = 1')
  } else if (resolvedLeftFilter.type === 'tag') {
    fromClause += `
      JOIN clipboard_item_tags cit ON cit.item_id = ci.id
      JOIN tags t ON t.id = cit.tag_id AND t.slug = ?`
    params.unshift(resolvedLeftFilter.slug)
  }

  if (contentType) {
    conditions.push('ci.content_type = ?')
    params.push(contentType)
  }

  if (sourceApp) {
    conditions.push("ci.source_app LIKE ?")
    params.push(`%"bundleId":"${sourceApp}"%`)
  }

  const itemColumns = includeContent ? 'ci.*' : ITEM_SUMMARY_COLUMNS
  let query = `
    SELECT ${itemColumns},
      (SELECT GROUP_CONCAT(t2.slug, ',')
       FROM clipboard_item_tags cit2
       JOIN tags t2 ON t2.id = cit2.tag_id
       WHERE cit2.item_id = ci.id) AS tag_slugs
    ${fromClause}`
  if (conditions.length > 0) {
    query += ' WHERE ' + conditions.join(' AND ')
  }
  const orderBy = sortBy === 'usage'
    ? 'ci.is_pinned DESC, ci.use_count DESC, ci.updated_at DESC'
    : 'ci.is_pinned DESC, ci.updated_at DESC'
  query += ` ORDER BY ${orderBy} LIMIT ? OFFSET ?`
  params.push(limit, offset)

  const items = db.prepare(query).all(...params) as ClipboardItem[]
  return items.map(maybeDecryptItem)
}

export function getItemById(id: string): ClipboardItem | undefined {
  const db = getDatabase()
  const item = db.prepare('SELECT * FROM clipboard_items WHERE id = ?').get(id) as
    | ClipboardItem
    | undefined
  return item ? maybeDecryptItem(item) : undefined
}

export function getItemContent(id: string): {
  content: string
  content_type: string
  metadata: string | null
} | undefined {
  const item = getItemById(id)
  if (!item) return undefined
  return {
    content: item.content,
    content_type: item.content_type,
    metadata: item.metadata
  }
}

export function getItemByHash(hash: string): ClipboardItem | undefined {
  const db = getDatabase()
  return db.prepare('SELECT * FROM clipboard_items WHERE content_hash = ?').get(hash) as
    | ClipboardItem
    | undefined
}

export function touchItem(id: string): void {
  const db = getDatabase()
  db.prepare('UPDATE clipboard_items SET updated_at = ? WHERE id = ?').run(Date.now(), id)
}

export function incrementUseCount(id: string): void {
  const db = getDatabase()
  db.prepare('UPDATE clipboard_items SET use_count = COALESCE(use_count, 0) + 1, updated_at = ? WHERE id = ?').run(Date.now(), id)
}

export function deleteItem(id: string): void {
  const db = getDatabase()
  db.prepare('DELETE FROM clipboard_items WHERE id = ?').run(id)
}

export function getStarredCount(): number {
  const db = getDatabase()
  const row = db.prepare('SELECT COUNT(*) as c FROM clipboard_items WHERE is_favorite = 1').get() as { c: number }
  return row.c
}

export function toggleFavorite(id: string): void {
  const db = getDatabase()
  const hasTag = (db.prepare(
    'SELECT COUNT(*) as c FROM clipboard_item_tags WHERE item_id = ?'
  ).get(id) as { c: number }).c > 0
  if (hasTag) return
  db.prepare(
    'UPDATE clipboard_items SET is_favorite = CASE WHEN is_favorite = 0 THEN 1 ELSE 0 END, updated_at = ? WHERE id = ?'
  ).run(Date.now(), id)
}

export function togglePin(id: string): void {
  const db = getDatabase()
  db.prepare(
    'UPDATE clipboard_items SET is_pinned = CASE WHEN is_pinned = 0 THEN 1 ELSE 0 END, updated_at = ? WHERE id = ?'
  ).run(Date.now(), id)
}

export function searchItems(query: string): ClipboardItem[] {
  const db = getDatabase()
  // Searching still reads the content column in SQLite, but returning only
  // summaries avoids copying up to 50 large results across IPC.
  const items = db
    .prepare(
      `SELECT ${ITEM_SUMMARY_COLUMNS},
        (SELECT GROUP_CONCAT(t.slug, ',')
         FROM clipboard_item_tags cit
         JOIN tags t ON t.id = cit.tag_id
         WHERE cit.item_id = ci.id) AS tag_slugs
       FROM clipboard_items ci
       WHERE ci.content LIKE ? OR ci.preview LIKE ? OR ci.title LIKE ?
       ORDER BY ci.is_pinned DESC, ci.updated_at DESC
       LIMIT 50`
    )
    .all(`%${query}%`, `%${query}%`, `%${query}%`) as ClipboardItem[]
  return items.map(maybeDecryptItem)
}

export function updateItemTitle(id: string, title: string | null): void {
  const db = getDatabase()
  db.prepare('UPDATE clipboard_items SET title = ?, updated_at = ? WHERE id = ?').run(
    title,
    Date.now(),
    id
  )
}

export function clearAll(): void {
  const db = getDatabase()
  db.prepare('DELETE FROM clipboard_items WHERE is_favorite = 0 AND is_pinned = 0').run()
}

export function getItemCount(): number {
  const db = getDatabase()
  const result = db.prepare('SELECT COUNT(*) as count FROM clipboard_items').get() as {
    count: number
  }
  return result.count
}

// Template types
export interface Template {
  id: string
  name: string
  content: string
  category_id: string | null
  sort_order: number
  created_at: number
  updated_at: number
}

export function getTemplates(): Template[] {
  const db = getDatabase()
  return db.prepare('SELECT * FROM templates ORDER BY sort_order ASC').all() as Template[]
}

export function createTemplate(
  id: string,
  name: string,
  content: string,
  categoryId?: string
): void {
  const db = getDatabase()
  const now = Date.now()
  db.prepare(
    'INSERT INTO templates (id, name, content, category_id, sort_order, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
  ).run(id, name, content, categoryId || null, 0, now, now)
}

export function updateTemplate(id: string, name: string, content: string): void {
  const db = getDatabase()
  db.prepare('UPDATE templates SET name = ?, content = ?, updated_at = ? WHERE id = ?').run(
    name,
    content,
    Date.now(),
    id
  )
}

export function deleteTemplate(id: string): void {
  const db = getDatabase()
  db.prepare('DELETE FROM templates WHERE id = ?').run(id)
}

// Category types
export interface Category {
  id: string
  name: string
  color: string | null
  sort_order: number
  created_at: number
}

export function getCategories(): Category[] {
  const db = getDatabase()
  return db.prepare('SELECT * FROM categories ORDER BY sort_order ASC').all() as Category[]
}

export function createCategory(id: string, name: string, color: string | null): void {
  const db = getDatabase()
  db.prepare(
    'INSERT INTO categories (id, name, color, sort_order, created_at) VALUES (?, ?, ?, ?, ?)'
  ).run(id, name, color, 0, Date.now())
}

export function deleteCategory(id: string): void {
  const db = getDatabase()
  db.prepare('UPDATE clipboard_items SET category_id = NULL WHERE category_id = ?').run(id)
  db.prepare('DELETE FROM categories WHERE id = ?').run(id)
}

export function updateItemCategory(itemId: string, categoryId: string | null): void {
  const db = getDatabase()
  db.prepare('UPDATE clipboard_items SET category_id = ?, updated_at = ? WHERE id = ?').run(
    categoryId,
    Date.now(),
    itemId
  )
}

export function autoCleanup(maxItems: number = 2000): void {
  const count = getItemCount()
  const deleteCount = getAutoCleanupDeleteCount(count, maxItems)

  if (deleteCount <= 0) return

  const db = getDatabase()
  db.prepare(
    `DELETE FROM clipboard_items
     WHERE id IN (
       SELECT id FROM clipboard_items
       WHERE is_favorite = 0 AND is_pinned = 0
         AND id NOT IN (SELECT DISTINCT item_id FROM clipboard_item_tags)
       ORDER BY updated_at ASC
       LIMIT ?
     )`
  ).run(deleteCount)
}

export function cleanupByRetention(days: number): void {
  if (days <= 0) return
  const db = getDatabase()
  const cutoff = Date.now() - days * 24 * 60 * 60 * 1000
  db.prepare(
    `DELETE FROM clipboard_items
     WHERE is_favorite = 0 AND is_pinned = 0
       AND id NOT IN (SELECT DISTINCT item_id FROM clipboard_item_tags)
       AND updated_at < ?`
  ).run(cutoff)
}

// ─── Tag CRUD ────────────────────────────────────────────────────────────────

export function listTagsWithCounts(): TagWithCount[] {
  const db = getDatabase()
  return db.prepare(`
    SELECT t.*, COUNT(cit.item_id) as count
    FROM tags t
    LEFT JOIN clipboard_item_tags cit ON cit.tag_id = t.id
    GROUP BY t.id
    ORDER BY t.last_used_at DESC, t.created_at DESC
  `).all() as TagWithCount[]
}

export function applyTags(itemId: string, slugs: string[]): void {
  if (slugs.length === 0) return
  const db = getDatabase()
  const now = Date.now()

  const getBySlug = db.prepare('SELECT id FROM tags WHERE slug = ?')
  const insertTag = db.prepare(
    'INSERT OR IGNORE INTO tags (id, slug, name, created_at, updated_at, last_used_at) VALUES (?, ?, ?, ?, ?, ?)'
  )
  const insertMapping = db.prepare(
    'INSERT OR IGNORE INTO clipboard_item_tags (item_id, tag_id, created_at) VALUES (?, ?, ?)'
  )
  const touchTag = db.prepare('UPDATE tags SET last_used_at = ?, updated_at = ? WHERE id = ?')

  const run = db.transaction(() => {
    for (const rawName of slugs) {
      const slug = toSlug(rawName)
      if (!slug) continue
      let existing = getBySlug.get(slug) as { id: string } | undefined
      let tagId: string
      if (existing) {
        tagId = existing.id
        touchTag.run(now, now, tagId)
      } else {
        tagId = `tag_${now}_${Math.random().toString(36).slice(2, 8)}`
        insertTag.run(tagId, slug, rawName, now, now, now)
      }
      insertMapping.run(itemId, tagId, now)
    }
    // Star/Tag 联动：打了标签自动取消 star
    db.prepare('UPDATE clipboard_items SET is_favorite = 0, updated_at = ? WHERE id = ?').run(now, itemId)
  })
  run()
}

export function removeTag(itemId: string, slug: string): void {
  const db = getDatabase()
  db.prepare(`
    DELETE FROM clipboard_item_tags
    WHERE item_id = ?
      AND tag_id = (SELECT id FROM tags WHERE slug = ?)
  `).run(itemId, slug)
}

export function getItemTagSlugs(itemId: string): string[] {
  const db = getDatabase()
  const rows = db.prepare(`
    SELECT t.slug FROM tags t
    JOIN clipboard_item_tags cit ON cit.tag_id = t.id
    WHERE cit.item_id = ?
  `).all(itemId) as { slug: string }[]
  return rows.map((r) => r.slug)
}

export function renameTag(slug: string, nextName: string): void {
  const db = getDatabase()
  const nextSlug = toSlug(nextName)
  db.prepare('UPDATE tags SET name = ?, slug = ?, updated_at = ? WHERE slug = ?').run(
    nextName, nextSlug, Date.now(), slug
  )
}

export function deleteTag(slug: string): void {
  const db = getDatabase()
  db.prepare('DELETE FROM tags WHERE slug = ?').run(slug)
}

export function mergeTag(sourceSlug: string, targetSlug: string): void {
  const db = getDatabase()
  const now = Date.now()

  const getTag = db.prepare('SELECT id FROM tags WHERE slug = ?')
  const source = getTag.get(sourceSlug) as { id: string } | undefined
  const target = getTag.get(targetSlug) as { id: string } | undefined
  if (!source || !target) return

  const run = db.transaction(() => {
    const itemsWithSource = db.prepare(
      'SELECT item_id FROM clipboard_item_tags WHERE tag_id = ?'
    ).all(source.id) as { item_id: string }[]

    for (const { item_id } of itemsWithSource) {
      db.prepare(
        'INSERT OR IGNORE INTO clipboard_item_tags (item_id, tag_id, created_at) VALUES (?, ?, ?)'
      ).run(item_id, target.id, now)
    }
    db.prepare('DELETE FROM tags WHERE id = ?').run(source.id)
    db.prepare('UPDATE tags SET last_used_at = ?, updated_at = ? WHERE id = ?').run(now, now, target.id)
  })
  run()
}

export function getTagStats(): { total: number; singleUse: number } {
  const db = getDatabase()
  const total = (db.prepare('SELECT COUNT(*) as c FROM tags').get() as { c: number }).c
  const singleUse = (db.prepare(`
    SELECT COUNT(*) as c FROM (
      SELECT tag_id FROM clipboard_item_tags GROUP BY tag_id HAVING COUNT(*) = 1
    )
  `).get() as { c: number }).c
  return { total, singleUse }
}

export function getSimilarTags(name: string): Tag[] {
  const db = getDatabase()
  const slug = toSlug(name)
  if (!slug) return []
  const pattern = `%${slug.replace(/-/g, '%')}%`
  return db.prepare('SELECT * FROM tags WHERE slug LIKE ? LIMIT 5').all(pattern) as Tag[]
}

export function getContentTypeCounts(options?: {
  leftFilter?: LeftFilter
  sourceApp?: string
}): Record<string, number> {
  const db = getDatabase()
  const conditions: string[] = []
  const params: unknown[] = []
  let fromClause = 'FROM clipboard_items ci'

  const leftFilter = options?.leftFilter ?? { type: 'all' as const }

  if (leftFilter.type === 'starred') {
    conditions.push('ci.is_favorite = 1')
  } else if (leftFilter.type === 'tag') {
    fromClause += `
      JOIN clipboard_item_tags cit ON cit.item_id = ci.id
      JOIN tags t ON t.id = cit.tag_id AND t.slug = ?`
    params.push(leftFilter.slug)
  }

  if (options?.sourceApp) {
    conditions.push('ci.source_app LIKE ?')
    params.push(`%"bundleId":"${options.sourceApp}"%`)
  }

  let query = `SELECT ci.content_type, COUNT(*) as count ${fromClause}`
  if (conditions.length > 0) {
    query += ' WHERE ' + conditions.join(' AND ')
  }
  query += ' GROUP BY ci.content_type'

  const rows = db.prepare(query).all(...params) as { content_type: string; count: number }[]
  const result: Record<string, number> = {}
  for (const row of rows) {
    result[row.content_type] = row.count
  }
  return result
}

export function getSourceApps(): { name: string; bundleId: string; count: number }[] {
  const db = getDatabase()
  const rows = db.prepare(`
    SELECT source_app, COUNT(*) as count
    FROM clipboard_items
    WHERE source_app IS NOT NULL
    GROUP BY source_app
    ORDER BY count DESC
  `).all() as { source_app: string; count: number }[]

  return rows.map((row) => {
    try {
      const parsed = JSON.parse(row.source_app)
      return { name: parsed.name, bundleId: parsed.bundleId, count: row.count }
    } catch {
      return { name: row.source_app, bundleId: '', count: row.count }
    }
  })
}
