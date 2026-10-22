#!/usr/bin/env node

/**
 * Stash License Key Generator
 *
 * Usage:
 *   node scripts/generate-license-keys.js [count]
 *
 * Examples:
 *   node scripts/generate-license-keys.js        # generate 10 keys
 *   node scripts/generate-license-keys.js 100     # generate 100 keys
 */

const CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

function isValidKey(code) {
  const digits = code.replace(/-/g, '').split('')
  let sum = 0
  for (let i = 0; i < digits.length; i++) {
    const val = parseInt(digits[i], 36)
    sum += i % 2 === 0 ? val : val * 2 > 35 ? val * 2 - 35 : val * 2
  }
  return sum % 10 === 0
}

function generateKey() {
  for (let attempt = 0; attempt < 10000; attempt++) {
    const parts = []
    for (let p = 0; p < 4; p++) {
      let seg = ''
      for (let i = 0; i < 4; i++) {
        seg += CHARS[Math.floor(Math.random() * CHARS.length)]
      }
      parts.push(seg)
    }
    const key = parts.join('-')
    if (isValidKey(key)) return key
  }
  throw new Error('Failed to generate valid key after 10000 attempts')
}

const count = parseInt(process.argv[2] || '10', 10)
const keys = new Set()

while (keys.size < count) {
  keys.add(generateKey())
}

for (const key of keys) {
  console.log(key)
}
