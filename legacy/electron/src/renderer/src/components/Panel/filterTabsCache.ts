export interface SourceAppCacheEntry {
  name: string
  bundleId: string
  count: number
}

let cachedSourceApps: SourceAppCacheEntry[] = []

export function getCachedSourceApps(): SourceAppCacheEntry[] {
  return cachedSourceApps
}

export function setCachedSourceApps(sourceApps: SourceAppCacheEntry[]): void {
  cachedSourceApps = sourceApps
}

export function clearCachedSourceApps(): void {
  cachedSourceApps = []
}
