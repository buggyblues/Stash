import test from 'node:test'
import assert from 'node:assert/strict'

import {
  clearCachedSourceApps,
  getCachedSourceApps,
  setCachedSourceApps
} from '../../src/renderer/src/components/Panel/filterTabsCache.ts'

test('cached source apps survive a FilterTabs remount', () => {
  clearCachedSourceApps()

  const sourceApps = [
    { name: 'Google Chrome', bundleId: 'com.google.Chrome', count: 12 },
    { name: 'Cursor', bundleId: 'com.todesktop.230313mzl4w4u92', count: 7 }
  ]

  setCachedSourceApps(sourceApps)

  assert.deepEqual(getCachedSourceApps(), sourceApps)
})
