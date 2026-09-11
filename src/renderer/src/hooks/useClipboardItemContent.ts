import { useEffect } from 'react'
import { useClipboardStore } from '../stores/clipboardStore'

/**
 * Resolve a clipboard item's full content only when a component needs it.
 * List rows can therefore stay backed by lightweight summary records.
 */
export function useClipboardItemContent(
  itemId: string,
  fallbackContent = '',
  enabled = true
): string {
  const storedContent = useClipboardStore((state) =>
    state.items.find((item) => item.id === itemId)?.content
  )
  const loadItemContent = useClipboardStore((state) => state.loadItemContent)
  const content = storedContent || fallbackContent

  useEffect(() => {
    if (!enabled || content) return
    void loadItemContent(itemId)
  }, [content, enabled, itemId, loadItemContent])

  return content
}
