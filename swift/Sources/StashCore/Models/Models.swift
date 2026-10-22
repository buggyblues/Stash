import Foundation

// MARK: - Content type

/// The set of clipboard content categories Stash recognises.
///
/// Raw values match the `content_type` column in the SQLite schema so that a
/// database written by the previous Electron build keeps working unchanged.
public enum ContentType: String, CaseIterable, Sendable {
    case text
    case code
    case url
    case json
    case color
    case image
    case base64
    case filePath = "file_path"

    /// Translation key used by the UI layer for the filter tabs / labels.
    public var localizationKey: String {
        switch self {
        case .text: return "panel.filter.text"
        case .code: return "panel.filter.code"
        case .url: return "panel.filter.url"
        case .json: return "panel.filter.json"
        case .color: return "panel.filter.color"
        case .image: return "panel.filter.image"
        case .base64: return "panel.filter.base64"
        case .filePath: return "panel.filter.filePath"
        }
    }

    /// Order used by the filter tab bar (matches the original UI).
    public static var filterOrder: [ContentType] {
        [.text, .code, .url, .json, .color, .image, .base64, .filePath]
    }
}

// MARK: - Clipboard item

/// A single clipboard history entry.
public struct ClipboardItem: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var content: String
    public var contentType: String
    public var contentHash: String
    public var preview: String?
    public var metadata: String?
    public var isFavorite: Bool
    public var isPinned: Bool
    public var sourceApp: String?
    public var tags: String?
    public var title: String?
    public var categoryId: String?
    public var createdAt: Int64
    public var updatedAt: Int64
    public var useCount: Int
    public var tagSlugs: String?

    public init(
        id: String,
        content: String,
        contentType: String,
        contentHash: String,
        preview: String? = nil,
        metadata: String? = nil,
        isFavorite: Bool = false,
        isPinned: Bool = false,
        sourceApp: String? = nil,
        tags: String? = nil,
        title: String? = nil,
        categoryId: String? = nil,
        createdAt: Int64,
        updatedAt: Int64,
        useCount: Int = 0,
        tagSlugs: String? = nil
    ) {
        self.id = id
        self.content = content
        self.contentType = contentType
        self.contentHash = contentHash
        self.preview = preview
        self.metadata = metadata
        self.isFavorite = isFavorite
        self.isPinned = isPinned
        self.sourceApp = sourceApp
        self.tags = tags
        self.title = title
        self.categoryId = categoryId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.useCount = useCount
        self.tagSlugs = tagSlugs
    }

    /// Parsed `source_app` payload (`{"name":…,"bundleId":…}`).
    public var sourceAppInfo: SourceApp? {
        guard let sourceApp, !sourceApp.isEmpty else { return nil }
        return SourceApp.decode(sourceApp)
    }

    /// Tag slugs attached to this item.
    public var tagSlugList: [String] {
        guard let tagSlugs, !tagSlugs.isEmpty else { return [] }
        return tagSlugs.split(separator: ",").map(String.init)
    }

    /// Decoded metadata dictionary, when the detector stored one.
    public var metadataDictionary: [String: Any] {
        guard let metadata, !metadata.isEmpty,
              let data = metadata.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any]
        else { return [:] }
        return dict
    }

    /// The preview text shown in the list, falling back to the raw content.
    public var displayPreview: String {
        if let preview, !preview.isEmpty { return preview }
        return content
    }

    // MARK: - Codable

    /// The JSON representation matches the column names of the database so the
    /// sync files stay interchangeable with the previous Electron build.
    private enum CodingKeys: String, CodingKey {
        case id
        case content
        case contentType = "content_type"
        case contentHash = "content_hash"
        case preview
        case metadata
        case isFavorite = "is_favorite"
        case isPinned = "is_pinned"
        case sourceApp = "source_app"
        case tags
        case title
        case categoryId = "category_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case useCount = "use_count"
        case tagSlugs = "tag_slugs"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(contentHash, forKey: .contentHash)
        try container.encodeIfPresent(preview, forKey: .preview)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(isFavorite ? 1 : 0, forKey: .isFavorite)
        try container.encode(isPinned ? 1 : 0, forKey: .isPinned)
        try container.encodeIfPresent(sourceApp, forKey: .sourceApp)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(useCount, forKey: .useCount)
        try container.encodeIfPresent(tagSlugs, forKey: .tagSlugs)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        contentType = try container.decode(String.self, forKey: .contentType)
        contentHash = try container.decode(String.self, forKey: .contentHash)
        preview = try container.decodeIfPresent(String.self, forKey: .preview)
        metadata = try container.decodeIfPresent(String.self, forKey: .metadata)
        let favorite = try container.decode(Int.self, forKey: .isFavorite)
        isFavorite = favorite != 0
        let pinned = try container.decode(Int.self, forKey: .isPinned)
        isPinned = pinned != 0
        sourceApp = try container.decodeIfPresent(String.self, forKey: .sourceApp)
        tags = try container.decodeIfPresent(String.self, forKey: .tags)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        createdAt = try container.decode(Int64.self, forKey: .createdAt)
        updatedAt = try container.decode(Int64.self, forKey: .updatedAt)
        useCount = try container.decodeIfPresent(Int.self, forKey: .useCount) ?? 0
        tagSlugs = try container.decodeIfPresent(String.self, forKey: .tagSlugs)
    }
}

// MARK: - Source app

/// The application a clipboard item was copied from.
public struct SourceApp: Equatable, Identifiable, Sendable {
    public var id: String { bundleId.isEmpty ? "legacy:" + name : bundleId }
    public var name: String
    public var bundleId: String
    public var count: Int

    public init(name: String, bundleId: String, count: Int = 0) {
        self.name = name
        self.bundleId = bundleId
        self.count = count
    }

    public static func decode(_ raw: String) -> SourceApp? {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any]
        else { return nil }
        guard let name = dict["name"] as? String else { return nil }
        let bundleId = dict["bundleId"] as? String ?? ""
        return SourceApp(name: name, bundleId: bundleId)
    }

    public func encoded() -> String {
        let payload: [String: String] = ["name": name, "bundleId": bundleId]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8)
        else { return "{}" }
        return text
    }
}

// MARK: - Tags

/// A user defined label that can be attached to clipboard items.
public struct Tag: Identifiable, Equatable, Sendable {
    public var id: String
    public var slug: String
    public var name: String
    public var createdAt: Int64
    public var updatedAt: Int64
    public var lastUsedAt: Int64?

    public init(
        id: String,
        slug: String,
        name: String,
        createdAt: Int64,
        updatedAt: Int64,
        lastUsedAt: Int64?
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
    }
}

/// A tag plus the number of items carrying it.
public struct TagWithCount: Identifiable, Equatable, Sendable {
    public var tag: Tag
    public var count: Int

    public var id: String { tag.id }
    public var slug: String { tag.slug }
    public var name: String { tag.name }
    public var lastUsedAt: Int64? { tag.lastUsedAt }

    public init(tag: Tag, count: Int) {
        self.tag = tag
        self.count = count
    }
}

// MARK: - Templates

/// A reusable text snippet.
public struct Template: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var content: String
    public var categoryId: String?
    public var sortOrder: Int
    public var createdAt: Int64
    public var updatedAt: Int64

    public init(
        id: String,
        name: String,
        content: String,
        categoryId: String?,
        sortOrder: Int,
        createdAt: Int64,
        updatedAt: Int64
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.categoryId = categoryId
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Categories

/// A manual grouping for clipboard items.
public struct Category: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var color: String?
    public var sortOrder: Int
    public var createdAt: Int64

    public init(
        id: String,
        name: String,
        color: String?,
        sortOrder: Int,
        createdAt: Int64
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

// MARK: - Filters

/// The filter applied by the panel's left sidebar.
public enum LeftFilter: Equatable, Sendable {
    case all
    case starred
    case tag(slug: String)

    public var isAll: Bool { if case .all = self { return true }; return false }
    public var isStarred: Bool { if case .starred = self { return true }; return false }

    public var slug: String? {
        if case let .tag(slug) = self { return slug }
        return nil
    }
}

/// Sort order for the clipboard list.
public enum SortBy: String, Equatable, Sendable {
    case recent
    case usage
}

/// Window placement of the main panel.
public enum LayoutMode: String, CaseIterable, Sendable {
    case center
    case side
    case bottom

    /// The cycle order used by the "cycle layout" shortcut: center → bottom → side.
    public static let cycle: [LayoutMode] = [.center, .bottom, .side]

    public func next() -> LayoutMode {
        guard let index = LayoutMode.cycle.firstIndex(of: self) else { return .center }
        return LayoutMode.cycle[(index + 1) % LayoutMode.cycle.count]
    }

    public var localizationKey: String {
        switch self {
        case .center: return "settings.general.layoutMode.center"
        case .side: return "settings.general.layoutMode.side"
        case .bottom: return "settings.general.layoutMode.bottom"
        }
    }
}

// MARK: - Theme

/// The user selectable theme mode.
public enum ThemeMode: String, CaseIterable, Sendable {
    case auto
    case dark
    case light

    public func resolved(systemTheme: ResolvedTheme) -> ResolvedTheme {
        self == .auto ? systemTheme : (self == .dark ? .dark : .light)
    }
}

/// A concrete light or dark appearance.
public enum ResolvedTheme: String, Sendable {
    case dark
    case light
}

// MARK: - Language

/// The languages the UI is translated into.
public enum AppLanguage: String, CaseIterable, Sendable {
    case simplifiedChinese = "zh-CN"
    case english = "en"
    case traditionalChinese = "zh-TW"

    public var localizationKey: String {
        switch self {
        case .simplifiedChinese: return "settings.general.language.zhCN"
        case .english: return "settings.general.language.en"
        case .traditionalChinese: return "settings.general.language.zhTW"
        }
    }

    /// Normalises a BCP-47 tag onto one of the supported languages.
    public static func normalize(_ raw: String?) -> AppLanguage {
        guard let raw, !raw.isEmpty else { return .simplifiedChinese }
        if raw.hasPrefix("zh-TW") || raw.hasPrefix("zh-Hant") { return .traditionalChinese }
        if raw.hasPrefix("zh") { return .simplifiedChinese }
        if raw.hasPrefix("en") { return .english }
        return .simplifiedChinese
    }
}

/// The language selection exposed in settings (`auto` follows the system).
public enum LanguageMode: String, CaseIterable, Sendable {
    case auto
    case simplifiedChinese = "zh-CN"
    case english = "en"
    case traditionalChinese = "zh-TW"

    public func resolved(systemLanguage: String?) -> AppLanguage {
        self == .auto
            ? AppLanguage.normalize(systemLanguage)
            : (AppLanguage(rawValue: rawValue) ?? .simplifiedChinese)
    }
}
