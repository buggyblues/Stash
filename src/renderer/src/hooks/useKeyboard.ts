import { useEffect, useCallback } from 'react'
import { useClipboardStore } from '../stores/clipboardStore'

export function useKeyboard(): void {
  const {
    items,
    selectedIndex,
    setSelectedIndex,
    pasteItem,
    deleteItem,
    setVisible,
    addToQueue,
    addMultipleToQueue,
    selectedItems,
    clearSelection
  } = useClipboardStore()

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      const target = document.activeElement?.tagName
      const isInput = target === 'INPUT' || target === 'TEXTAREA'

      switch (e.key) {
        case 'ArrowDown':
          e.preventDefault()
          setSelectedIndex(Math.min(selectedIndex + 1, items.length - 1))
          break
        case 'ArrowUp':
          e.preventDefault()
          setSelectedIndex(Math.max(selectedIndex - 1, 0))
          break
        case 'Enter':
          e.preventDefault()
          if (selectedItems.size > 0) {
            // Add all selected items to queue
            const selected = items.filter((i) => selectedItems.has(i.id))
            addMultipleToQueue(selected)
            selected.forEach((i) => window.api.queueAdd({ id: i.id, content: i.content, content_type: i.content_type }))
            clearSelection()
          } else if (items[selectedIndex]) {
            pasteItem(items[selectedIndex].id)
          }
          break
        case ' ':
          if (isInput) return
          e.preventDefault()
          if (items[selectedIndex]) {
            const item = items[selectedIndex]
            addToQueue(item)
            window.api.queueAdd({ id: item.id, content: item.content, content_type: item.content_type })
          }
          break
        case 'Escape':
          e.preventDefault()
          if (selectedItems.size > 0) {
            clearSelection()
          } else {
            setVisible(false)
            window.electron.ipcRenderer.send('panel:close')
          }
          break
        default:
          // Cmd+Number 1-9 for quick select
          if (e.key >= '1' && e.key <= '9' && e.metaKey && !e.ctrlKey && !e.altKey) {
            const index = parseInt(e.key) - 1
            if (index < items.length) {
              e.preventDefault()
              pasteItem(items[index].id)
            }
            return
          }
          // 'd' to delete current item
          if (e.key === 'd' && !e.metaKey && !e.ctrlKey && !e.altKey) {
            if (isInput) return
            if (items[selectedIndex]) {
              e.preventDefault()
              deleteItem(items[selectedIndex].id)
            }
            return
          }
          // Printable character → focus search bar and let it type
          if (
            !isInput &&
            !e.metaKey && !e.ctrlKey && !e.altKey &&
            e.key.length === 1 && /[a-zA-Z0-9]/.test(e.key)
          ) {
            const searchInput = document.querySelector<HTMLInputElement>('input[type="text"]')
            if (searchInput) {
              searchInput.focus()
            }
          }
      }
    },
    [
      items,
      selectedIndex,
      setSelectedIndex,
      pasteItem,
      deleteItem,
      setVisible,
      addToQueue,
      addMultipleToQueue,
      selectedItems,
      clearSelection
    ]
  )

  useEffect(() => {
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [handleKeyDown])
}
