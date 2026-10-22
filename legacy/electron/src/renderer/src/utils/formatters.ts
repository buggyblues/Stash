export function formatJSON(input: string): { formatted: string; valid: boolean; error?: string } {
  try {
    const parsed = JSON.parse(input)
    return { formatted: JSON.stringify(parsed, null, 2), valid: true }
  } catch {
    return { formatted: input, valid: false }
  }
}

export function decodeBase64(input: string): { decoded: string; valid: boolean } {
  try {
    const decoded = atob(input.trim())
    return { decoded, valid: true }
  } catch {
    return { decoded: '', valid: false }
  }
}

export function encodeBase64(input: string): string {
  return btoa(input)
}

export function encodeURL(input: string): string {
  return encodeURIComponent(input)
}

export function decodeURL(input: string): string {
  try {
    return decodeURIComponent(input)
  } catch {
    return input
  }
}
