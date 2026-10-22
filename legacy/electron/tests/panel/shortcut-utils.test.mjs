import test from 'node:test'
import assert from 'node:assert/strict'

import { eventToShortcut, matchShortcut } from '../../src/renderer/src/utils/shortcut.ts'

test('matchShortcut handles alt letter shortcuts using physical key identity', () => {
  const keyboardEvent = {
    key: '@',
    code: 'KeyL',
    metaKey: false,
    ctrlKey: false,
    shiftKey: false,
    altKey: true,
  }

  assert.equal(matchShortcut(keyboardEvent, 'Alt+L'), true)
})

test('eventToShortcut records alt letter shortcuts from physical key identity', () => {
  const keyboardEvent = {
    key: '@',
    code: 'KeyL',
    metaKey: false,
    ctrlKey: false,
    shiftKey: false,
    altKey: true,
  }

  assert.equal(eventToShortcut(keyboardEvent), 'Alt+L')
})
