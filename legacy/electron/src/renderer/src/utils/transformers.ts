export function toUpperCase(s: string): string {
  return s.toUpperCase()
}

export function toLowerCase(s: string): string {
  return s.toLowerCase()
}

export function toTitleCase(s: string): string {
  return s.replace(/\b\w/g, (c) => c.toUpperCase())
}

export function toCamelCase(s: string): string {
  return s
    .replace(/[-_\s]+(.)?/g, (_, c) => (c ? c.toUpperCase() : ''))
    .replace(/^[A-Z]/, (c) => c.toLowerCase())
}

export function toSnakeCase(s: string): string {
  return s
    .replace(/([a-z])([A-Z])/g, '$1_$2')
    .replace(/[-\s]+/g, '_')
    .toLowerCase()
}

export function toKebabCase(s: string): string {
  return s
    .replace(/([a-z])([A-Z])/g, '$1-$2')
    .replace(/[_\s]+/g, '-')
    .toLowerCase()
}

export function trimWhitespace(s: string): string {
  return s.trim()
}

export function removeAllWhitespace(s: string): string {
  return s.replace(/\s+/g, '')
}
