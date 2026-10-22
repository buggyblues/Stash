import { useState, useEffect } from 'react'

const iconCache = new Map<string, string | null>()
const pendingRequests = new Set<string>()
const listeners = new Map<string, Set<(icon: string | null) => void>>()

export function useAppIcon(bundleId: string | undefined): string | null {
  const [icon, setIcon] = useState<string | null>(
    bundleId ? (iconCache.get(bundleId) ?? null) : null
  )

  useEffect(() => {
    if (!bundleId) return

    if (iconCache.has(bundleId)) {
      setIcon(iconCache.get(bundleId)!)
      return
    }

    // Register listener
    if (!listeners.has(bundleId)) {
      listeners.set(bundleId, new Set())
    }
    const listenerSet = listeners.get(bundleId)!
    listenerSet.add(setIcon)

    // Start fetch if not already pending
    if (!pendingRequests.has(bundleId)) {
      pendingRequests.add(bundleId)
      window.api.getAppIcon(bundleId).then((result) => {
        iconCache.set(bundleId, result)
        pendingRequests.delete(bundleId)
        const fns = listeners.get(bundleId)
        if (fns) {
          fns.forEach((fn) => fn(result))
          listeners.delete(bundleId)
        }
      })
    }

    return () => {
      listenerSet.delete(setIcon)
    }
  }, [bundleId])

  return icon
}
