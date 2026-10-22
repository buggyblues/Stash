export interface ContextMenuPoint {
  x: number
  y: number
}

export interface ContextMenuSize {
  width: number
  height: number
}

export interface ContextMenuViewport {
  width: number
  height: number
}

export function getContextMenuPosition(
  anchor: ContextMenuPoint,
  menu: ContextMenuSize,
  viewport: ContextMenuViewport,
  margin = 12
): { left: number; top: number } {
  const maxLeft = Math.max(margin, viewport.width - menu.width - margin)
  const maxTop = Math.max(margin, viewport.height - menu.height - margin)

  return {
    left: Math.min(Math.max(anchor.x, margin), maxLeft),
    top: Math.min(Math.max(anchor.y, margin), maxTop),
  }
}
