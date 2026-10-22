import { create } from 'zustand'

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

interface ClipboardState {
  items: ClipboardItem[]
  itemsRevision: number
  selectedIndex: number
  searchQuery: string
  isVisible: boolean
  filterType: string | null
  leftFilter: LeftFilter
  previewCollapsed: boolean
  filtersCollapsed: boolean
  tagBarCollapsed: boolean
  typeFilterCollapsed: boolean
  sourceAppFilterCollapsed: boolean
  sortBy: 'recent' | 'usage'
  sourceAppFilter: string | null
  starredCount: number
  hasMore: boolean
  isLoadingMore: boolean

  // Sequence paste queue
  sequenceQueue: ClipboardItem[]
  queueIndex: number
  isQueueActive: boolean
  selectedItems: Set<string>

  addToQueue: (item: ClipboardItem) => void
  addMultipleToQueue: (items: ClipboardItem[]) => void
  removeFromQueue: (index: number) => void
  clearQueue: () => void
  toggleSelectItem: (id: string) => void
  clearSelection: () => void
  isItemSelected: (id: string) => boolean
  isItemInQueue: (id: string) => boolean
  getQueuePosition: (id: string) => number

  loadItems: () => Promise<void>
  loadItemContent: (id: string) => Promise<string | null>
  loadStarredCount: () => Promise<void>
  addItem: (item: ClipboardItem) => void
  setSelectedIndex: (index: number) => void
  setSearchQuery: (query: string) => void
  setVisible: (visible: boolean) => void
  setFilterType: (type: string | null) => void
  setLeftFilter: (filter: LeftFilter) => void
  setSourceAppFilter: (bundleId: string | null) => void
  setSortBy: (sortBy: 'recent' | 'usage') => void
  togglePreview: () => void
  toggleFilters: () => void
  toggleTagBar: () => void
  toggleTypeFilter: () => void
  toggleSourceAppFilter: () => void
  deleteItem: (id: string) => Promise<void>
  toggleFavorite: (id: string) => Promise<void>
  togglePin: (id: string) => Promise<void>
  pasteItem: (id: string) => Promise<void>
  updateTitle: (id: string, title: string | null) => Promise<void>
  clearAll: () => Promise<void>
  search: (query: string) => Promise<void>
  loadNextPage: () => Promise<void>
}

export const useClipboardStore = create<ClipboardState>((set, get) => ({
  items: [],
  itemsRevision: 0,
  selectedIndex: 0,
  searchQuery: '',
  isVisible: false,
  filterType: null,
  leftFilter: { type: 'all' },
  previewCollapsed: false,
  filtersCollapsed: false,
  tagBarCollapsed: false,
  typeFilterCollapsed: false,
  sourceAppFilterCollapsed: false,
  sourceAppFilter: null,
  sortBy: 'recent',
  starredCount: 0,
  hasMore: true,
  isLoadingMore: false,

  // Sequence paste queue
  sequenceQueue: [],
  queueIndex: 0,
  isQueueActive: false,
  selectedItems: new Set<string>(),

  addToQueue: (item) => {
    set((state) => {
      if (state.sequenceQueue.some((q) => q.id === item.id)) return state
      return {
        sequenceQueue: [...state.sequenceQueue, item],
        isQueueActive: true
      }
    })
  },

  addMultipleToQueue: (items) => {
    set((state) => {
      const existingIds = new Set(state.sequenceQueue.map((q) => q.id))
      const newItems = items.filter((i) => !existingIds.has(i.id))
      if (newItems.length === 0) return state
      return {
        sequenceQueue: [...state.sequenceQueue, ...newItems],
        isQueueActive: true
      }
    })
  },

  removeFromQueue: (index) => {
    set((state) => {
      const newQueue = [...state.sequenceQueue]
      newQueue.splice(index, 1)
      const newIndex =
        state.queueIndex >= newQueue.length
          ? Math.max(0, newQueue.length - 1)
          : state.queueIndex
      return {
        sequenceQueue: newQueue,
        queueIndex: newIndex,
        isQueueActive: newQueue.length > 0
      }
    })
  },

  clearQueue: () => {
    set({ sequenceQueue: [], queueIndex: 0, isQueueActive: false })
  },

  toggleSelectItem: (id) => {
    set((state) => {
      const newSet = new Set(state.selectedItems)
      if (newSet.has(id)) {
        newSet.delete(id)
      } else {
        newSet.add(id)
      }
      return { selectedItems: newSet }
    })
  },

  clearSelection: () => {
    set({ selectedItems: new Set<string>() })
  },

  isItemSelected: (id) => {
    return get().selectedItems.has(id)
  },

  isItemInQueue: (id) => {
    return get().sequenceQueue.some((q) => q.id === id)
  },

  getQueuePosition: (id) => {
    return get().sequenceQueue.findIndex((q) => q.id === id) + 1
  },

  loadItems: async () => {
    const state = get()
    const items = await window.api.getItems({
      limit: 50,
      contentType: state.filterType || undefined,
      leftFilter: state.leftFilter,
      sourceApp: state.sourceAppFilter || undefined,
      sortBy: state.sortBy,
      includeContent: false
    })
    const loadedContent = new Map(
      state.items
        .filter((item) => item.content)
        .map((item) => [item.id, item.content])
    )
    const mergedItems = items.map((item) => {
      const content = loadedContent.get(item.id)
      return content ? { ...item, content } : item
    })
    set((prev) => ({
      items: mergedItems,
      itemsRevision: prev.itemsRevision + 1,
      selectedIndex: 0,
      hasMore: items.length >= 50
    }))
    get().loadStarredCount()
  },

  loadItemContent: async (id) => {
    const current = get().items.find((item) => item.id === id)
    if (current?.content) return current.content

    const pending = pendingContentRequests.get(id)
    if (pending) return pending

    const request = window.api
      .getItemContent(id)
      .then((result) => {
        if (!result) return null
        set((state) => {
          const item = state.items.find((candidate) => candidate.id === id)
          if (!item || item.content === result.content) return state
          return {
            items: state.items.map((candidate) =>
              candidate.id === id
                ? {
                    ...candidate,
                    content: result.content,
                    content_type: result.content_type,
                    metadata: result.metadata
                  }
                : candidate
            )
          }
        })
        return result.content
      })
      .catch(() => null)
      .finally(() => {
        pendingContentRequests.delete(id)
      })

    pendingContentRequests.set(id, request)
    return request
  },

  loadNextPage: async () => {
    const state = get()
    if (state.isLoadingMore || !state.hasMore || state.searchQuery.trim()) return
    set({ isLoadingMore: true })
    try {
      const moreItems = await window.api.getItems({
        limit: 50,
        offset: state.items.length,
        contentType: state.filterType || undefined,
        leftFilter: state.leftFilter,
        sourceApp: state.sourceAppFilter || undefined,
        sortBy: state.sortBy,
        includeContent: false
      })
      set((prev) => ({
        items: [...prev.items, ...moreItems],
        hasMore: moreItems.length >= 50
      }))
    } finally {
      set({ isLoadingMore: false })
    }
  },

  loadStarredCount: async () => {
    const count = await window.api.getStarredCount()
    set({ starredCount: count })
  },

  addItem: (item) => {
    set((state) => ({
      items: [item, ...state.items.filter((i) => i.id !== item.id)].slice(0, 200),
      itemsRevision: state.itemsRevision + 1
    }))
  },

  setSelectedIndex: (index) => set({ selectedIndex: index }),

  setSearchQuery: (query) => set({ searchQuery: query }),

  setVisible: (visible) => {
    set({ isVisible: visible })
    if (visible) {
      set({ searchQuery: '', selectedIndex: 0 })
    }
  },

  setFilterType: (type) => {
    set({ filterType: type })
    get().loadItems()
    syncWidgetFilter(get())
  },

  setLeftFilter: (filter) => {
    set({ leftFilter: filter })
    get().loadItems()
    syncWidgetFilter(get())
  },

  setSourceAppFilter: (bundleId) => {
    set({ sourceAppFilter: bundleId })
    get().loadItems()
    syncWidgetFilter(get())
  },

  setSortBy: (sortBy) => {
    set({ sortBy })
    get().loadItems()
    syncWidgetFilter(get())
  },

  togglePreview: () => set((state) => ({ previewCollapsed: !state.previewCollapsed })),
  toggleFilters: () => set((state) => ({ filtersCollapsed: !state.filtersCollapsed })),
  toggleTagBar: () => set((state) => ({ tagBarCollapsed: !state.tagBarCollapsed })),
  toggleTypeFilter: () => set((state) => ({ typeFilterCollapsed: !state.typeFilterCollapsed })),
  toggleSourceAppFilter: () => set((state) => ({ sourceAppFilterCollapsed: !state.sourceAppFilterCollapsed })),

  deleteItem: async (id) => {
    await window.api.deleteItem(id)
    set((state) => ({
      items: state.items.filter((i) => i.id !== id),
      itemsRevision: state.itemsRevision + 1
    }))
  },

  toggleFavorite: async (id) => {
    await window.api.toggleFavorite(id)
    set((state) => ({
      items: state.items.map((i) =>
        i.id === id ? { ...i, is_favorite: i.is_favorite ? 0 : 1 } : i
      ),
      itemsRevision: state.itemsRevision + 1
    }))
  },

  togglePin: async (id) => {
    await window.api.togglePin(id)
    set((state) => ({
      items: state.items.map((i) => (i.id === id ? { ...i, is_pinned: i.is_pinned ? 0 : 1 } : i)),
      itemsRevision: state.itemsRevision + 1
    }))
  },

  pasteItem: async (id) => {
    await window.api.pasteItem(id)
  },

  updateTitle: async (id, title) => {
    await window.api.updateItemTitle(id, title)
    set((state) => ({
      items: state.items.map((i) => (i.id === id ? { ...i, title } : i))
    }))
  },

  clearAll: async () => {
    await window.api.clearAll()
    get().loadItems()
  },

  search: async (query) => {
    set({ searchQuery: query })
    if (!query.trim()) {
      get().loadItems()
      return
    }
    const items = await window.api.searchItems(query)
    set((prev) => ({
      items,
      itemsRevision: prev.itemsRevision + 1,
      selectedIndex: 0,
      hasMore: false
    }))
  }
}))

const pendingContentRequests = new Map<string, Promise<string | null>>()

function syncWidgetFilter(state: ClipboardState): void {
  window.api.widgetSyncFilter?.({
    contentType: state.filterType || undefined,
    leftFilter: state.leftFilter,
    sourceApp: state.sourceAppFilter || undefined,
    sortBy: state.sortBy
  })
}
