import Combine
import Foundation
import StashCore

/// The state of the clipboard panel.
///
/// It mirrors the previous `clipboardStore.ts`, including the selection model,
/// the filter combinations, the lazy content loading and the paste queue.
///
/// The model is confined to the main actor: the item list is read from
/// background tasks as well, so it must not be mutated concurrently.
@MainActor
public final class PanelViewModel: ObservableObject {
    // MARK: - List state

    @Published public var items: [ClipboardItem] = []
    @Published public var itemsRevision = 0
    @Published public var selectedIndex = 0
    @Published public var searchQuery = ""
    @Published public var hasMore = true
    @Published public var isLoadingMore = false
    @Published public var starredCount = 0

    // MARK: - Filters

    @Published public var filterType: String?
    @Published public var leftFilter: LeftFilter = .all
    @Published public var sourceAppFilter: String?
    @Published public var sortBy: SortBy = .recent

    // MARK: - Collapsed regions

    @Published public var previewCollapsed = false
    @Published public var filtersCollapsed = false
    @Published public var tagBarCollapsed = false
    @Published public var typeFilterCollapsed = false
    @Published public var sourceAppFilterCollapsed = false

    // MARK: - Queue & multi selection

    @Published public var sequenceQueue: [ClipboardItem] = []
    @Published public var selectedItems: Set<String> = []

    // MARK: - Related data

    @Published public var tags: [TagWithCount] = []
    @Published public var sourceApps: [SourceApp] = []
    @Published public var typeCounts: [String: Int] = [:]

    // MARK: - Transient UI state

    @Published public var previewItemId: String?
    @Published public var editingItemId: String?
    @Published public var tagPickerItemId: String?
    @Published public var tagPickerQuery = ""
    @Published public var tagPickerCursor = 0
    /// The tag slugs currently applied to the item the picker was opened for.
    @Published public var appliedTagSlugs: Set<String> = []
    @Published public var isVisible = false
    /// Set while an inline title editor is open. The editor consumes the
    /// Enter and Escape keys before the panel handles them.
    @Published public var isEditingTitle = false
    /// Set when a clipboard item was captured while the panel was hidden. The
    /// list is reloaded the next time the panel becomes visible so that the
    /// active filters are applied again.
    @Published public var hasPendingReload = false

    // MARK: - Dependencies

    private let repository: Repository
    private var pendingContentRequests: [String: Task<String?, Never>] = [:]
    private var previewTask: Task<Void, Never>?

    /// The database the panel reads from.
    public var database: Repository { repository }

    /// Called when an item should be pasted into the previously active app.
    public var onPaste: ((ClipboardItem) -> Void)?
    /// Called when the panel should close.
    public var onHide: (() -> Void)?
    /// Called when the filter selection changed and the widget should follow.
    public var onFilterChanged: (() -> Void)?
    public var onDataChanged: (() -> Void)?

    public init(repository: Repository) {
        self.repository = repository
    }

    // MARK: - Derived state

    public var selectedItem: ClipboardItem? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    public var isQueueActive: Bool { !sequenceQueue.isEmpty }

    public func isItemSelected(_ id: String) -> Bool { selectedItems.contains(id) }

    public func isItemInQueue(_ id: String) -> Bool { sequenceQueue.contains { $0.id == id } }

    public func queuePosition(for id: String) -> Int {
        (sequenceQueue.firstIndex { $0.id == id } ?? -1) + 1
    }

    // MARK: - Loading

    public func loadItems() {
        let options = GetItemsOptions(
            limit: 50,
            offset: 0,
            contentType: filterType,
            favoritesOnly: false,
            leftFilter: leftFilter,
            sourceApp: sourceAppFilter,
            sortBy: sortBy,
            includeContent: false,
            searchQuery: searchQuery
        )

        let loadedContent = Dictionary(
            uniqueKeysWithValues: items.filter { !$0.content.isEmpty }.map { ($0.id, $0.content) }
        )

        do {
            let fetched = try repository.getItems(options: options)
            items = fetched.map { item -> ClipboardItem in
                guard let content = loadedContent[item.id] else { return item }
                var copy = item
                copy.content = content
                return copy
            }
            itemsRevision += 1
            selectedIndex = 0
            hasMore = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && fetched.count >= 50
            selectedItems.formIntersection(Set(items.map(\.id)))
            updatePreviewSelection()
        } catch {
            NSLog("[Panel] failed to load items: \(error.localizedDescription)")
        }

        loadStarredCount()
        loadTypeCounts()
        loadSourceApps()
    }

    public func loadNextPage() {
        guard !isLoadingMore, hasMore, searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let options = GetItemsOptions(
            limit: 50,
            offset: items.count,
            contentType: filterType,
            favoritesOnly: false,
            leftFilter: leftFilter,
            sourceApp: sourceAppFilter,
            sortBy: sortBy,
            includeContent: false
        )

        do {
            let more = try repository.getItems(options: options)
            items.append(contentsOf: more)
            hasMore = more.count >= 50
        } catch {
            NSLog("[Panel] failed to load more items: \(error.localizedDescription)")
        }
    }

    public func loadStarredCount() {
        starredCount = (try? repository.getStarredCount()) ?? 0
    }

    public func loadTypeCounts() {
        let counts = (try? repository.getContentTypeCounts(
            options: ContentTypeCountsOptions(leftFilter: leftFilter, sourceApp: sourceAppFilter)
        )) ?? [:]
        typeCounts = counts
    }

    public func loadSourceApps() {
        sourceApps = (try? repository.getSourceApps()) ?? []
    }

    public func loadTags() {
        tags = (try? repository.listTagsWithCounts()) ?? []
    }

    /// Loads the (potentially large) content of an item on demand.
    public func loadItemContent(_ id: String) async -> String? {
        if let existing = items.first(where: { $0.id == id }), !existing.content.isEmpty {
            return existing.content
        }
        if let pending = pendingContentRequests[id] {
            return await pending.value
        }

        let repository = self.repository
        let task = Task<String?, Never> { [repository] in
            // The database read happens off the main actor.
            let result = await Task.detached(priority: .userInitiated) {
                try? repository.getItemContent(id)
            }.value
            guard let result else { return nil }
            await MainActor.run {
                guard let index = self.items.firstIndex(where: { $0.id == id }) else { return }
                self.items[index].content = result.content
                self.items[index].contentType = result.contentType
                self.items[index].metadata = result.metadata
            }
            return result.content
        }
        pendingContentRequests[id] = task
        let value = await task.value
        pendingContentRequests.removeValue(forKey: id)
        return value
    }

    // MARK: - Search

    public func search(_ query: String) {
        searchQuery = query
        loadItems()
    }

    // MARK: - Filters

    public func setFilterType(_ type: String?) {
        filterType = type
        loadItems()
        onFilterChanged?()
    }

    public func setLeftFilter(_ filter: LeftFilter) {
        leftFilter = filter
        loadItems()
        loadTags()
        onFilterChanged?()
    }

    public func setSourceAppFilter(_ bundleId: String?) {
        sourceAppFilter = bundleId
        loadItems()
        onFilterChanged?()
    }

    public func setSortBy(_ sort: SortBy) {
        sortBy = sort
        loadItems()
        onFilterChanged?()
    }

    public func toggleFilters() { filtersCollapsed.toggle() }
    public func toggleTagBar() { tagBarCollapsed.toggle() }
    public func toggleTypeFilter() { typeFilterCollapsed.toggle() }
    public func toggleSourceAppFilter() { sourceAppFilterCollapsed.toggle() }
    public func togglePreview() { previewCollapsed.toggle() }

    // MARK: - Selection

    public func setSelectedIndex(_ index: Int) {
        guard !items.isEmpty else {
            selectedIndex = 0
            return
        }
        selectedIndex = min(max(index, 0), items.count - 1)
    }

    public func moveSelection(by offset: Int) {
        setSelectedIndex(selectedIndex + offset)
    }

    public func toggleSelectItem(_ id: String) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }

    public func clearSelection() {
        selectedItems.removeAll()
    }

    /// The item whose preview is shown. It follows the selection after a
    /// short delay, exactly like the previous implementation.
    public func updatePreviewSelection() {
        previewTask?.cancel()
        let target = selectedItem?.id
        previewTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.previewItemId = target
            }
        }
    }

    public var previewItem: ClipboardItem? {
        guard let previewItemId else { return nil }
        return items.first { $0.id == previewItemId }
    }

    // MARK: - Item actions

    public func deleteItem(_ id: String) {
        do {
            try repository.deleteItem(id)
            let index = selectedIndex
            selectedItems.remove(id)
            if editingItemId == id { editingItemId = nil }
            loadItems()
            setSelectedIndex(index)
            updatePreviewSelection()
            loadTags()
            onDataChanged?()
        } catch { NSLog("[Panel] delete failed: \(error)") }
    }

    public func toggleFavorite(_ id: String) {
        do {
            try repository.toggleFavorite(id)
            refreshAfterMutation()
        } catch { NSLog("[Panel] favorite failed: \(error)") }
    }

    public func togglePin(_ id: String) {
        do {
            try repository.togglePin(id)
            refreshAfterMutation()
        } catch { NSLog("[Panel] pin failed: \(error)") }
    }

    public func updateTitle(_ id: String, title: String?) {
        do {
            try repository.updateItemTitle(id, title: title)
            refreshAfterMutation()
        } catch { NSLog("[Panel] title failed: \(error)") }
    }

    public func clearAll() {
        do {
            try repository.clearAll()
            loadItems()
            loadTags()
            onDataChanged?()
        } catch { NSLog("[Panel] clear failed: \(error)") }
    }

    private func refreshAfterMutation() {
        let selection = selectedItem?.id
        loadItems()
        if let selection, let index = items.firstIndex(where: { $0.id == selection }) {
            selectedIndex = index
        }
        updatePreviewSelection()
        loadTags()
        onDataChanged?()
    }

    public func openEditor(for id: String) {
        guard let item = items.first(where: { $0.id == id }), item.contentType != ContentType.image.rawValue else { return }
        editingItemId = id
        previewCollapsed = false
    }

    public func pasteItem(_ id: String) {
        guard items.contains(where: { $0.id == id }) else { return }
        // The list is loaded without the content column, so the full row is
        // read again before it is written to the pasteboard.
        if let full = try? repository.getItemById(id) {
            onPaste?(full)
        }
    }

    public func addItem(_ item: ClipboardItem) {
        hasPendingReload = true
        if isVisible {
            refreshAfterMutation()
            hasPendingReload = false
        }
    }

    /// Reloads the list when items were captured while the panel was hidden.
    public func reloadIfNeeded() {
        guard hasPendingReload else { return }
        hasPendingReload = false
        loadItems()
    }

    // MARK: - Queue

    public func addToQueue(_ item: ClipboardItem) {
        guard !sequenceQueue.contains(where: { $0.id == item.id }) else { return }
        sequenceQueue.append(item)
    }

    public func addMultipleToQueue(_ newItems: [ClipboardItem]) {
        let existing = Set(sequenceQueue.map(\.id))
        let additions = newItems.filter { !existing.contains($0.id) }
        guard !additions.isEmpty else { return }
        sequenceQueue.append(contentsOf: additions)
    }

    public func removeFromQueue(at index: Int) {
        guard sequenceQueue.indices.contains(index) else { return }
        sequenceQueue.remove(at: index)
    }

    public func clearQueue() {
        sequenceQueue.removeAll()
    }

    // MARK: - Tags

    public func applyTags(_ itemId: String, slugs: [String]) {
        do {
            try repository.applyTags(itemId: itemId, slugs: slugs)
            refreshAfterMutation()
        } catch { NSLog("[Panel] tagging failed: \(error)") }
    }

    public func removeTag(_ itemId: String, slug: String) {
        do {
            try repository.removeTag(itemId: itemId, slug: slug)
            refreshAfterMutation()
        } catch { NSLog("[Panel] untagging failed: \(error)") }
    }

    public func tagSlugs(for itemId: String) -> [String] {
        (try? repository.getItemTagSlugs(itemId)) ?? []
    }

    public func similarTags(to name: String) -> [Tag] {
        let slug = Slug.make(name)
        guard !slug.isEmpty else { return [] }
        let exact = slug
        return ((try? repository.getSimilarTags(name: name)) ?? []).filter { $0.slug != exact }
    }

    /// The tags shown in the picker for the given query.
    public func filteredTags(query: String) -> [TagWithCount] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return tags }
        let slug = Slug.make(trimmed)
        let lowered = trimmed.lowercased()
        return tags.filter { $0.slug.contains(slug) || $0.name.lowercased().contains(lowered) }
    }

    // MARK: - Tag picker

    /// The tags currently offered by the tag picker.
    public var tagPickerOptions: [TagWithCount] {
        filteredTags(query: tagPickerQuery)
    }

    /// Whether the tag picker offers to create a new tag.
    public var tagPickerCanCreate: Bool {
        let trimmed = tagPickerQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let slug = Slug.make(trimmed)
        return !tags.contains { $0.slug == slug }
    }

    /// Opens the tag picker for an item.
    public func openTagPicker(for itemId: String) {
        tagPickerItemId = itemId
        tagPickerQuery = ""
        tagPickerCursor = 0
        appliedTagSlugs = Set(tagSlugs(for: itemId))
    }

    /// Closes the tag picker.
    public func closeTagPicker() {
        tagPickerItemId = nil
        tagPickerQuery = ""
        tagPickerCursor = 0
    }

    /// Moves the keyboard cursor of the tag picker.
    public func moveTagPickerCursor(by offset: Int) {
        let total = tagPickerOptions.count + (tagPickerCanCreate ? 1 : 0)
        guard total > 0 else {
            tagPickerCursor = 0
            return
        }
        tagPickerCursor = min(max(tagPickerCursor + offset, 0), total - 1)
    }

    /// Applies the option the keyboard cursor is on.
    public func applyTagPickerCursor() {
        let options = tagPickerOptions
        if tagPickerCursor < options.count {
            let tag = options[tagPickerCursor]
            toggleTag(slug: tag.slug, name: tag.name)
        } else if tagPickerCanCreate {
            createTag(name: tagPickerQuery.trimmingCharacters(in: .whitespaces))
        }
    }

    /// Adds or removes a tag on the item the picker was opened for.
    public func toggleTag(slug: String, name: String) {
        guard let itemId = tagPickerItemId else { return }
        if appliedTagSlugs.contains(slug) {
            removeTag(itemId, slug: slug)
        } else {
            applyTags(itemId, slugs: [name])
        }
        appliedTagSlugs = Set(tagSlugs(for: itemId))
    }

    /// Creates a new tag and applies it.
    public func createTag(name: String) {
        guard let itemId = tagPickerItemId else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let slug = Slug.make(trimmed)
        guard !slug.isEmpty else { return }
        applyTags(itemId, slugs: [trimmed])
        appliedTagSlugs = Set(tagSlugs(for: itemId))
        tagPickerQuery = ""
        tagPickerCursor = 0
    }
}
