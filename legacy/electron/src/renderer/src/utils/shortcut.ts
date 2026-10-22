/**
 * Match a KeyboardEvent against a shortcut string like "CommandOrControl+F", "Alt", "T".
 */
export function matchShortcut(e: KeyboardEvent, shortcut: string): boolean {
  const parts = shortcut.split('+')
  const key = parts[parts.length - 1]
  const modifiers = parts.slice(0, -1).map((m) => m.toLowerCase())

  const needMeta = modifiers.includes('commandorcontrol') || modifiers.includes('cmd')
  const needShift = modifiers.includes('shift')
  const needAlt = modifiers.includes('alt')

  // Modifier-only shortcut (e.g. "Alt")
  if (parts.length === 1) {
    const solo = key.toLowerCase()
    if (solo === 'alt') return e.key === 'Alt' && !e.metaKey && !e.ctrlKey && !e.shiftKey
    if (solo === 'shift') return e.key === 'Shift' && !e.metaKey && !e.ctrlKey && !e.altKey
    // Single character key (no modifiers)
    return e.key.toLowerCase() === solo && !e.metaKey && !e.ctrlKey && !e.altKey && !e.shiftKey
  }

  if (needMeta !== (e.metaKey || e.ctrlKey)) return false
  if (needShift !== e.shiftKey) return false
  if (needAlt !== e.altKey) return false

  return getShortcutKey(e).toLowerCase() === key.toLowerCase()
}

/**
 * Convert a KeyboardEvent to a shortcut string for the recorder.
 */
export function eventToShortcut(e: KeyboardEvent): string | null {
  const parts: string[] = []
  const key = e.key

  // Ignore standalone modifier key presses while recording combo
  const isModifier = ['Meta', 'Control', 'Shift', 'Alt'].includes(key)

  if (e.metaKey || e.ctrlKey) parts.push('CommandOrControl')
  if (e.shiftKey) parts.push('Shift')
  if (e.altKey) parts.push('Alt')

  // Allow modifier-only shortcuts (e.g. just "Alt")
  if (isModifier && parts.length === 1) {
    return parts[0] === 'CommandOrControl' ? null : parts[0]
  }
  if (isModifier) return null

  // Map special keys
  const keyMap: Record<string, string> = {
    ' ': 'Space',
    ',': ',',
    ';': ';',
    "'": "'",
    '/': '/',
    '.': '.',
    '-': '-',
    '=': '='
  }

  const mapped = keyMap[key] || getShortcutKey(e)
  parts.push(mapped)

  return parts.join('+')
}

/**
 * Format a shortcut string for display (e.g. "CommandOrControl+F" → "⌘ F")
 */
export function formatShortcut(shortcut: string): string {
  return shortcut
    .replace('CommandOrControl', '⌘')
    .replace('Shift', '⇧')
    .replace('Alt', '⌥')
    .replace('Space', '␣')
    .replace(/\+/g, ' ')
}

function getShortcutKey(e: Pick<KeyboardEvent, 'key' | 'code'>): string {
  const code = e.code || ''

  if (code.startsWith('Key')) {
    return code.slice(3).toUpperCase()
  }

  if (code.startsWith('Digit')) {
    return code.slice(5)
  }

  const codeMap: Record<string, string> = {
    Space: 'Space',
    Comma: ',',
    Period: '.',
    Semicolon: ';',
    Quote: "'",
    Slash: '/',
    Minus: '-',
    Equal: '=',
    Backquote: '`',
    Backslash: '\\',
    BracketLeft: '[',
    BracketRight: ']',
  }

  return codeMap[code] || e.key.toUpperCase()
}
