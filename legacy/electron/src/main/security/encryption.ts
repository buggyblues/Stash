import { createCipheriv, createDecipheriv, randomBytes, pbkdf2Sync } from 'crypto'

const ALGORITHM = 'aes-256-gcm'
const KEY_LENGTH = 32
const IV_LENGTH = 16
const SALT_LENGTH = 32
const PBKDF2_ITERATIONS = 100000
const PBKDF2_DIGEST = 'sha512'

export function deriveKey(password: string, salt: Buffer): Buffer {
  return pbkdf2Sync(password, salt, PBKDF2_ITERATIONS, KEY_LENGTH, PBKDF2_DIGEST)
}

export function generateSalt(): Buffer {
  return randomBytes(SALT_LENGTH)
}

export function encrypt(
  plaintext: string,
  key: Buffer
): { ciphertext: string; iv: string; tag: string } {
  const iv = randomBytes(IV_LENGTH)
  const cipher = createCipheriv(ALGORITHM, key, iv)

  let encrypted = cipher.update(plaintext, 'utf8', 'base64')
  encrypted += cipher.final('base64')

  const tag = cipher.getAuthTag()

  return {
    ciphertext: encrypted,
    iv: iv.toString('base64'),
    tag: tag.toString('base64')
  }
}

export function decrypt(
  ciphertext: string,
  iv: string,
  tag: string,
  key: Buffer
): string {
  const decipher = createDecipheriv(ALGORITHM, key, Buffer.from(iv, 'base64'))
  decipher.setAuthTag(Buffer.from(tag, 'base64'))

  let decrypted = decipher.update(ciphertext, 'base64', 'utf8')
  decrypted += decipher.final('utf8')

  return decrypted
}

export interface EncryptedPayload {
  ciphertext: string
  iv: string
  tag: string
  salt: string
}

export function encryptWithPassword(plaintext: string, password: string): EncryptedPayload {
  const salt = generateSalt()
  const key = deriveKey(password, salt)
  const { ciphertext, iv, tag } = encrypt(plaintext, key)

  return {
    ciphertext,
    iv,
    tag,
    salt: salt.toString('base64')
  }
}

export function decryptWithPassword(payload: EncryptedPayload, password: string): string {
  const salt = Buffer.from(payload.salt, 'base64')
  const key = deriveKey(password, salt)
  return decrypt(payload.ciphertext, payload.iv, payload.tag, key)
}

let cachedKey: Buffer | null = null
let cachedSalt: Buffer | null = null

export function setEncryptionPassword(password: string, salt?: Buffer): void {
  cachedSalt = salt || generateSalt()
  cachedKey = deriveKey(password, cachedSalt)
}

export function clearEncryptionKey(): void {
  cachedKey = null
  cachedSalt = null
}

export function isKeySet(): boolean {
  return cachedKey !== null
}

export function encryptContent(plaintext: string): string | null {
  if (!cachedKey) return null
  const result = encrypt(plaintext, cachedKey)
  return JSON.stringify(result)
}

export function decryptContent(encryptedJson: string): string | null {
  if (!cachedKey) return null
  try {
    const { ciphertext, iv, tag } = JSON.parse(encryptedJson)
    return decrypt(ciphertext, iv, tag, cachedKey)
  } catch {
    return null
  }
}

export function getSalt(): string | null {
  return cachedSalt ? cachedSalt.toString('base64') : null
}
