import test from 'node:test'
import assert from 'node:assert/strict'

import {
  MAX_ITEMS_CUSTOM_MIN,
  MAX_ITEMS_PRESETS,
  getAutoCleanupDeleteCount,
  normalizeMaxItems,
} from '../src/shared/max-items.ts'

test('normalizeMaxItems keeps preset values and custom values above the minimum', () => {
  assert.deepEqual(MAX_ITEMS_PRESETS, [500, 1000, 2000])
  assert.equal(normalizeMaxItems(500), 500)
  assert.equal(normalizeMaxItems(1600), 1600)
  assert.equal(MAX_ITEMS_CUSTOM_MIN, 500)
})

test('normalizeMaxItems treats 0 as unlimited and clamps smaller custom values up to 500', () => {
  assert.equal(normalizeMaxItems(0), 0)
  assert.equal(normalizeMaxItems(1), 500)
  assert.equal(normalizeMaxItems(499), 500)
  assert.equal(normalizeMaxItems(-100), 0)
})

test('getAutoCleanupDeleteCount skips cleanup for unlimited and deletes the overflow otherwise', () => {
  assert.equal(getAutoCleanupDeleteCount(3200, 0), 0)
  assert.equal(getAutoCleanupDeleteCount(3200, 2000), 1200)
  assert.equal(getAutoCleanupDeleteCount(3200, 499), 2700)
})
