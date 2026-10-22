import { clipboard } from 'electron'
import { createHash } from 'crypto'
import { execSync } from 'child_process'
import { BrowserWindow } from 'electron'
import { detectContentType } from './detector'
import * as repository from '../database/repository'
import { nanoid } from 'nanoid'
import { writeFileSync, existsSync, mkdirSync } from 'fs'
import { join } from 'path'
import { app } from 'electron'

const MAX_IMAGE_BASE64_SIZE = 5 * 1024 * 1024

export class ClipboardMonitor {
  private intervalId: ReturnType<typeof setInterval> | null = null
  private lastTextHash: string = ''
  private lastImageHash: string = ''
  private polling = false

  start(): void {
    if (this.intervalId) return
    this.intervalId = setInterval(() => this.poll(), 500)
  }

  stop(): void {
    if (this.intervalId) {
      clearInterval(this.intervalId)
      this.intervalId = null
    }
  }

  private poll(): void {
    if (this.polling) return
    this.polling = true
    try {
      const textChanged = this.checkText()
      // Skip image check if text just changed (likely the same clipboard event)
      if (!textChanged) {
        this.checkImage()
      }
    } finally {
      this.polling = false
    }
  }

  private checkText(): boolean {
    const text = clipboard.readText()
    if (!text || text.trim().length === 0) return false

    const hash = this.computeHash(text)
    if (hash === this.lastTextHash) return false
    this.lastTextHash = hash

    const existing = repository.getItemByHash(hash)
    if (existing) {
      repository.touchItem(existing.id)
      this.notifyRenderer(existing)
      return true
    }

    const { type, metadata } = detectContentType(text)
    const preview = text.substring(0, 200)

    const item = {
      id: nanoid(),
      content: text,
      content_type: type,
      content_hash: hash,
      preview,
      metadata: metadata ? JSON.stringify(metadata) : null,
      is_favorite: 0,
      is_pinned: 0,
      source_app: this.getFrontmostApp(),
      tags: null,
      title: null,
      category_id: null,
      created_at: Date.now(),
      updated_at: Date.now(),
      use_count: 0
    }

    repository.insertItem(item)
    this.notifyRenderer(item)
    return true
  }

  private checkImage(): void {
    const image = clipboard.readImage()
    if (image.isEmpty()) return

    const buffer = image.toPNG()
    const hash = this.computeHash(buffer)
    if (hash === this.lastImageHash) return
    this.lastImageHash = hash

    const existing = repository.getItemByHash(hash)
    if (existing) {
      repository.touchItem(existing.id)
      return
    }

    const size = image.getSize()
    let content: string

    if (buffer.length > MAX_IMAGE_BASE64_SIZE) {
      const imgDir = join(app.getPath('userData'), 'images')
      if (!existsSync(imgDir)) mkdirSync(imgDir, { recursive: true })
      const filePath = join(imgDir, `${nanoid()}.png`)
      writeFileSync(filePath, buffer)
      content = filePath
    } else {
      content = buffer.toString('base64')
    }

    const item = {
      id: nanoid(),
      content,
      content_type: 'image' as const,
      content_hash: hash,
      preview: `Image ${size.width}x${size.height}`,
      metadata: JSON.stringify({ width: size.width, height: size.height }),
      is_favorite: 0,
      is_pinned: 0,
      source_app: this.getFrontmostApp(),
      tags: null,
      title: null,
      category_id: null,
      created_at: Date.now(),
      updated_at: Date.now(),
      use_count: 0
    }

    repository.insertItem(item)
    this.notifyRenderer(item)
  }

  private getFrontmostApp(): string | null {
    try {
      const result = execSync(
        `osascript -e 'tell application "System Events"' -e 'set fp to first application process whose frontmost is true' -e 'set appName to name of fp' -e 'set bid to bundle identifier of fp' -e 'return appName & "|" & bid' -e 'end tell'`,
        { encoding: 'utf-8', timeout: 1000, stdio: ['pipe', 'pipe', 'pipe'] }
      ).trim()
      const sep = result.indexOf('|')
      if (sep === -1) return null
      const name = result.substring(0, sep).trim()
      const bundleId = result.substring(sep + 1).trim()
      if (name && bundleId && bundleId !== 'com.apple.loginwindow') {
        return JSON.stringify({ name, bundleId })
      }
      return null
    } catch {
      return null
    }
  }

  private computeHash(data: string | Buffer): string {
    return createHash('sha256').update(data).digest('hex')
  }

  private notifyRenderer(item: unknown): void {
    const windows = BrowserWindow.getAllWindows()
    for (const win of windows) {
      win.webContents.send('clipboard:newItem', item)
    }
  }
}
