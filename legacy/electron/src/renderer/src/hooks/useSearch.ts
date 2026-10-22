import { useClipboardStore } from '../stores/clipboardStore'
import type { ClipboardItem } from '../stores/clipboardStore'

export function useSearch(): ClipboardItem[] {
  return useClipboardStore((state) => state.items)
}
