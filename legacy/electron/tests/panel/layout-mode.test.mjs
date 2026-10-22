import test from 'node:test'
import assert from 'node:assert/strict'

import { cycleLayoutMode } from '../../src/shared/layout-mode.ts'

test('cycleLayoutMode rotates center to bottom to side to center', () => {
  assert.equal(cycleLayoutMode('center'), 'bottom')
  assert.equal(cycleLayoutMode('bottom'), 'side')
  assert.equal(cycleLayoutMode('side'), 'center')
})
