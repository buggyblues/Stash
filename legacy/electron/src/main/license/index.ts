import { getDatabase } from '../database/connection'

const TRIAL_DAYS = 14
const CODE_REGEX = /^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/

export type LicenseType = 'trial' | 'activated' | 'expired'

export interface LicenseStatus {
  type: LicenseType
  trialDaysLeft: number
  activationCode: string | null
}

function getSetting(key: string): string | null {
  const db = getDatabase()
  const row = db.prepare('SELECT value FROM app_settings WHERE key = ?').get(key) as
    | { value: string }
    | undefined
  return row?.value ?? null
}

function setSetting(key: string, value: string): void {
  const db = getDatabase()
  db.prepare('INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)').run(key, value)
}

function deleteSetting(key: string): void {
  const db = getDatabase()
  db.prepare('DELETE FROM app_settings WHERE key = ?').run(key)
}

function ensureTrialStarted(): number {
  let raw = getSetting('trial_start_at')
  if (!raw) {
    const now = Date.now()
    setSetting('trial_start_at', String(now))
    return now
  }
  return Number(raw)
}

function computeTrialDaysLeft(trialStart: number): number {
  const elapsed = Date.now() - trialStart
  const remaining = TRIAL_DAYS - Math.floor(elapsed / (24 * 60 * 60 * 1000))
  return Math.max(0, remaining)
}

export function getLicenseStatus(): LicenseStatus {
  const code = getSetting('activation_code')
  if (code) {
    return { type: 'activated', trialDaysLeft: 0, activationCode: code }
  }

  const trialStart = ensureTrialStarted()
  const daysLeft = computeTrialDaysLeft(trialStart)

  return {
    type: daysLeft > 0 ? 'trial' : 'expired',
    trialDaysLeft: daysLeft,
    activationCode: null,
  }
}

/** Validate format + Luhn-like checksum on the numeric values of each character */
function isValidCode(code: string): boolean {
  if (!CODE_REGEX.test(code)) return false

  const digits = code.replace(/-/g, '').split('')
  let sum = 0
  for (let i = 0; i < digits.length; i++) {
    const val = parseInt(digits[i], 36)
    sum += i % 2 === 0 ? val : val * 2 > 35 ? val * 2 - 35 : val * 2
  }
  return sum % 10 === 0
}

export function activateLicense(code: string): { ok: boolean; error?: string } {
  const normalized = code.trim().toUpperCase()
  if (!isValidCode(normalized)) {
    return { ok: false, error: 'invalid_code' }
  }
  setSetting('activation_code', normalized)
  return { ok: true }
}

export function deactivateLicense(): void {
  deleteSetting('activation_code')
}
