import test from 'node:test'
import assert from 'node:assert/strict'

import { showToast } from '../src/renderer/src/utils/toast.ts'

function createFakeElement(tagName) {
  return {
    tagName,
    id: '',
    className: '',
    textContent: '',
    style: {},
    removed: false,
    remove() {
      this.removed = true
    },
  }
}

function createFakeDocument() {
  const elements = new Map()

  return {
    body: {
      appendChild(element) {
        elements.set(element.id, element)
      },
    },
    createElement(tagName) {
      return createFakeElement(tagName)
    },
    getElementById(id) {
      const element = elements.get(id)
      return element && !element.removed ? element : null
    },
  }
}

function createFakeTimers() {
  let nextId = 1
  const scheduled = new Map()

  return {
    setTimeout(callback, delay) {
      const id = nextId++
      scheduled.set(id, { callback, delay })
      return id
    },
    clearTimeout(id) {
      scheduled.delete(id)
    },
    runNext(delay) {
      const entry = [...scheduled.entries()].find(([, value]) => value.delay === delay)
      if (!entry) throw new Error(`No timer found for delay ${delay}`)
      const [id, { callback }] = entry
      scheduled.delete(id)
      callback()
    },
  }
}

test('showToast creates a floating toast with the shared style and message', () => {
  const document = createFakeDocument()
  const timers = createFakeTimers()

  showToast('已保存', {
    document,
    setTimeout: timers.setTimeout,
    clearTimeout: timers.clearTimeout,
  })

  const element = document.getElementById('zpaste-toast')
  assert.ok(element)
  assert.equal(element.textContent, '已保存')
  assert.match(element.className, /fixed bottom-4 left-1\/2/)
  assert.equal(element.style.opacity, '1')
})

test('showToast reuses the existing toast element and removes it after the timeout', () => {
  const document = createFakeDocument()
  const timers = createFakeTimers()

  showToast('第一次', {
    document,
    setTimeout: timers.setTimeout,
    clearTimeout: timers.clearTimeout,
  })
  showToast('第二次', {
    document,
    setTimeout: timers.setTimeout,
    clearTimeout: timers.clearTimeout,
  })

  const element = document.getElementById('zpaste-toast')
  assert.equal(element?.textContent, '第二次')

  timers.runNext(2000)
  assert.equal(element?.style.opacity, '0')
  timers.runNext(200)
  assert.equal(element?.removed, true)
})
