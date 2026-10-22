import { create } from 'zustand'

export interface TagWithCount {
  id: string
  slug: string
  name: string
  created_at: number
  updated_at: number
  last_used_at: number | null
  count: number
}

interface TagState {
  tags: TagWithCount[]
  loadTags: () => Promise<void>
  applyTags: (itemId: string, slugs: string[]) => Promise<void>
  removeTag: (itemId: string, slug: string) => Promise<void>
  renameTag: (slug: string, nextName: string) => Promise<void>
  deleteTag: (slug: string) => Promise<void>
  mergeTag: (sourceSlug: string, targetSlug: string) => Promise<void>
}

export const useTagStore = create<TagState>((set, get) => ({
  tags: [],

  loadTags: async () => {
    const tags = await window.api.listTags()
    set({ tags })
  },

  applyTags: async (itemId, slugs) => {
    await window.api.applyTags(itemId, slugs)
    get().loadTags()
  },

  removeTag: async (itemId, slug) => {
    await window.api.removeTag(itemId, slug)
    get().loadTags()
  },

  renameTag: async (slug, nextName) => {
    await window.api.renameTag(slug, nextName)
    get().loadTags()
  },

  deleteTag: async (slug) => {
    await window.api.deleteTag(slug)
    get().loadTags()
  },

  mergeTag: async (sourceSlug, targetSlug) => {
    await window.api.mergeTag(sourceSlug, targetSlug)
    get().loadTags()
  }
}))
