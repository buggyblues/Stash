export type LayoutMode = 'center' | 'side' | 'bottom'

const layoutCycle: LayoutMode[] = ['center', 'bottom', 'side']

export function cycleLayoutMode(mode: LayoutMode): LayoutMode {
  const currentIndex = layoutCycle.indexOf(mode)
  if (currentIndex === -1) {
    return layoutCycle[0]
  }

  return layoutCycle[(currentIndex + 1) % layoutCycle.length]
}
