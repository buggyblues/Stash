import React, { useRef, useEffect, useCallback, useState } from 'react'
import { useTranslation } from 'react-i18next'
import ClipboardItemRow from './ClipboardItem'
import { useSearch } from '../../hooks/useSearch'
import { useClipboardStore } from '../../stores/clipboardStore'

interface Props {
  onDoubleClick?: (itemId: string) => void
  onOpenTagPicker?: (itemId: string) => void
}

const DEFAULT_HEIGHT = 68
const IMAGE_HEIGHT = 82

function getItemHeight(contentType: string): number {
  return contentType === 'image' ? IMAGE_HEIGHT : DEFAULT_HEIGHT
}

export default function ClipboardList({ onDoubleClick, onOpenTagPicker }: Props): React.JSX.Element {
  const items = useSearch()
  const hasMore = useClipboardStore((s) => s.hasMore)
  const isLoadingMore = useClipboardStore((s) => s.isLoadingMore)
  const { t } = useTranslation()
  const containerRef = useRef<HTMLDivElement>(null)
  const [scrollTop, setScrollTop] = useState(0)
  const [containerHeight, setContainerHeight] = useState(400)

  // 预计算每项的 top offset
  const offsets = React.useMemo(() => {
    const arr: number[] = []
    let acc = 0
    for (const item of items) {
      arr.push(acc)
      acc += getItemHeight(item.content_type)
    }
    arr.push(acc) // sentinel: total height
    return arr
  }, [items])

  // Keep a ref to offsets so the subscribe callback always has the latest value
  const offsetsRef = useRef(offsets)
  useEffect(() => {
    offsetsRef.current = offsets
  }, [offsets])

  // Keep a ref to items for the same reason
  const itemsRef = useRef(items)
  useEffect(() => {
    itemsRef.current = items
  }, [items])

  const totalHeight = offsets[offsets.length - 1] ?? 0

  useEffect(() => {
    const el = containerRef.current
    if (!el) return
    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) {
        setContainerHeight(entry.contentRect.height)
      }
    })
    observer.observe(el)
    setContainerHeight(el.clientHeight)
    return () => observer.disconnect()
  }, [])

  // Subscribe to selectedIndex changes without re-rendering ClipboardList
  useEffect(() => {
    let prevIndex = useClipboardStore.getState().selectedIndex
    return useClipboardStore.subscribe((state) => {
      const selectedIndex = state.selectedIndex
      if (selectedIndex === prevIndex) return
      prevIndex = selectedIndex
      const el = containerRef.current
      if (!el || selectedIndex < 0) return
      const offs = offsetsRef.current
      const its = itemsRef.current
      const itemTop = offs[selectedIndex] ?? 0
      const itemBottom = itemTop + getItemHeight(its[selectedIndex]?.content_type ?? '')
      const viewTop = el.scrollTop
      const viewBottom = viewTop + el.clientHeight

      if (itemTop < viewTop) {
        el.scrollTop = itemTop
      } else if (itemBottom > viewBottom) {
        el.scrollTop = itemBottom - el.clientHeight
      }
    })
  }, [])

  const handleScroll = useCallback((e: React.UIEvent<HTMLDivElement>) => {
    const el = e.currentTarget
    setScrollTop(el.scrollTop)

    // 检测滚动到底部，触发加载更多
    const scrollPos = el.scrollTop + el.clientHeight
    const total = el.scrollHeight
    if (total - scrollPos < 200) {
      useClipboardStore.getState().loadNextPage()
    }
  }, [])

  if (items.length === 0) {
    return (
      <div className="flex flex-1 items-center justify-center px-5 py-8 text-sm text-muted-foreground">
        <div className="max-w-xs rounded-[1.25rem] border border-border/60 bg-card px-6 py-8 text-center shadow-sm">
          <p className="mb-3 text-3xl">📋</p>
          <p className="text-base font-semibold text-foreground">{t('panel.empty.title')}</p>
          <p className="mt-2 text-xs leading-6 text-muted-foreground">{t('panel.empty.subtitle')}</p>
        </div>
      </div>
    )
  }

  // 二分找第一个可见项
  let startIndex = 0
  let lo = 0, hi = items.length - 1
  while (lo <= hi) {
    const mid = (lo + hi) >> 1
    if ((offsets[mid + 1] ?? 0) <= scrollTop) lo = mid + 1
    else { startIndex = mid; hi = mid - 1 }
  }
  startIndex = Math.max(0, startIndex - 2)

  const visibleItems: React.JSX.Element[] = []
  for (let i = startIndex; i < items.length; i++) {
    const top = offsets[i] ?? 0
    if (top > scrollTop + containerHeight + DEFAULT_HEIGHT * 3) break
    const item = items[i]
    if (!item) continue
    visibleItems.push(
      <div
        key={item.id}
        style={{
          position: 'absolute',
          top,
          left: 0,
          right: 0,
          height: getItemHeight(item.content_type)
        }}
      >
        <ClipboardItemRow
          item={item}
          index={i}
          onDoubleClick={onDoubleClick}
          onOpenTagPicker={onOpenTagPicker}
        />
      </div>
    )
  }

  const LOADING_HEIGHT = 48
  const listTotalHeight = totalHeight + (hasMore ? LOADING_HEIGHT : 0)

  return (
    <div
      ref={containerRef}
      className="flex-1 overflow-y-auto px-1.5 py-1.5"
      onScroll={handleScroll}
    >
      <div style={{ position: 'relative', height: listTotalHeight, width: '100%' }}>
        {visibleItems}
        {isLoadingMore && (
          <div
            style={{ position: 'absolute', top: totalHeight, left: 0, right: 0, height: LOADING_HEIGHT }}
            className="flex items-center justify-center text-xs text-muted-foreground"
          >
            {t('panel.loadingMore')}
          </div>
        )}
      </div>
    </div>
  )
}
