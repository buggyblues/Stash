import test from 'node:test'
import assert from 'node:assert/strict'

import { getContextMenuPosition } from '../src/renderer/src/utils/contextMenu.ts'

test('getContextMenuPosition keeps the menu inside the viewport near the bottom-right corner', () => {
  const position = getContextMenuPosition(
    { x: 960, y: 620 },
    { width: 220, height: 260 },
    { width: 1000, height: 680 }
  )

  assert.deepEqual(position, {
    left: 768,
    top: 408,
  })
})

test('getContextMenuPosition keeps a minimum margin near the top-left corner', () => {
  const position = getContextMenuPosition(
    { x: 4, y: 6 },
    { width: 220, height: 260 },
    { width: 1000, height: 680 }
  )

  assert.deepEqual(position, {
    left: 12,
    top: 12,
  })
})
