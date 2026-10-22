export const MAX_ITEMS_UNLIMITED = 0
export const MAX_ITEMS_CUSTOM_MIN = 500
export const MAX_ITEMS_PRESETS = [500, 1000, 2000] as const
export const DEFAULT_MAX_ITEMS = 2000

export function normalizeMaxItems(value: number): number {
  if (!Number.isFinite(value)) return DEFAULT_MAX_ITEMS

  const normalized = Math.trunc(value)

  if (normalized <= MAX_ITEMS_UNLIMITED) {
    return MAX_ITEMS_UNLIMITED
  }

  return Math.max(normalized, MAX_ITEMS_CUSTOM_MIN)
}

export function isPresetMaxItems(value: number): boolean {
  return MAX_ITEMS_PRESETS.includes(value as (typeof MAX_ITEMS_PRESETS)[number])
}

export function getAutoCleanupDeleteCount(count: number, maxItems: number): number {
  const normalized = normalizeMaxItems(maxItems)

  if (normalized === MAX_ITEMS_UNLIMITED || count <= normalized) {
    return 0
  }

  return count - normalized
}
