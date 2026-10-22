import { existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync } from 'fs'
import { join } from 'path'
import { homedir, hostname } from 'os'
import { randomUUID } from 'crypto'
import { app } from 'electron'
import * as repository from '../database/repository'
import type { ClipboardItem } from '../database/repository'
import {
  encryptWithPassword,
  decryptWithPassword,
  type EncryptedPayload
} from '../security/encryption'

interface ChangeRecord {
  operation: 'add' | 'update' | 'delete'
  item: ClipboardItem
  timestamp: number
  deviceId: string
}

interface SyncFile {
  deviceId: string
  changes: ChangeRecord[]
  exportedAt: number
}

interface EncryptedSyncFile {
  version: 2
  encrypted: true
  data: EncryptedPayload
}

interface SyncState {
  lastSyncTime: number
  processedFiles: string[]
}

export class iCloudSync {
  private syncDir: string
  private syncInterval: ReturnType<typeof setInterval> | null = null
  private deviceId: string
  private lastSyncTime: number = 0
  private processedFiles: Set<string> = new Set()
  private stateFile: string
  private syncPassword: string | null = null

  constructor(syncPassword?: string) {
    this.syncDir = join(
      homedir(),
      'Library/Mobile Documents/com~apple~CloudDocs/ZPaste'
    )
    this.stateFile = join(app.getPath('userData'), 'sync-state.json')
    this.deviceId = this.getDeviceId()
    this.syncPassword = syncPassword || null
    this.loadSyncState()
  }

  setSyncPassword(password: string | null): void {
    this.syncPassword = password
  }

  start(): void {
    if (this.syncInterval) return

    this.ensureSyncDir()
    this.fullSync()

    this.syncInterval = setInterval(() => {
      this.exportChanges()
      this.importChanges()
    }, 5 * 60 * 1000)
  }

  stop(): void {
    if (this.syncInterval) {
      clearInterval(this.syncInterval)
      this.syncInterval = null
    }
  }

  exportChanges(): void {
    try {
      this.ensureSyncDir()

      // Clean up old sync files from this device before exporting
      this.cleanupOldSyncFiles()

      const items = repository.getItems({ limit: 2000 })
      const changes: ChangeRecord[] = items
        .filter((item) => item.updated_at > this.lastSyncTime)
        .map((item) => ({
          operation: 'add' as const,
          item,
          timestamp: item.updated_at,
          deviceId: this.deviceId
        }))

      if (changes.length === 0) return

      const syncFile: SyncFile = {
        deviceId: this.deviceId,
        changes,
        exportedAt: Date.now()
      }

      const filename = `sync_${this.deviceId}_${Date.now()}.json`
      const plaintext = JSON.stringify(syncFile)

      if (this.syncPassword) {
        const encrypted = encryptWithPassword(plaintext, this.syncPassword)
        const encryptedFile: EncryptedSyncFile = {
          version: 2,
          encrypted: true,
          data: encrypted
        }
        writeFileSync(join(this.syncDir, filename), JSON.stringify(encryptedFile), 'utf-8')
      } else {
        console.warn('[iCloudSync] no sync password set, writing plaintext (insecure)')
        writeFileSync(join(this.syncDir, filename), JSON.stringify(syncFile, null, 2), 'utf-8')
      }

      this.lastSyncTime = Date.now()
      this.saveSyncState()
    } catch (error) {
      console.error('[iCloudSync] export error:', error)
    }
  }

  importChanges(): void {
    try {
      this.ensureSyncDir()
      const files = readdirSync(this.syncDir).filter(
        (f) => f.startsWith('sync_') && f.endsWith('.json') && !f.includes(this.deviceId)
      )

      for (const file of files) {
        if (this.processedFiles.has(file)) continue

        try {
          const content = readFileSync(join(this.syncDir, file), 'utf-8')
          const syncFile = this.parseSyncFile(content)

          if (!syncFile) {
            console.warn(`[iCloudSync] skipping ${file}: unable to decrypt or parse`)
            continue
          }

          for (const change of syncFile.changes) {
            this.applyChange(change)
          }

          this.processedFiles.add(file)
        } catch {
          console.error(`[iCloudSync] failed to import ${file}`)
        }
      }

      this.saveSyncState()
    } catch (error) {
      console.error('[iCloudSync] import error:', error)
    }
  }

  /** Parse sync file content, handling both encrypted (v2) and legacy plaintext formats */
  private parseSyncFile(content: string): SyncFile | null {
    try {
      const parsed = JSON.parse(content)

      // Encrypted format (version 2)
      if (parsed.version === 2 && parsed.encrypted === true) {
        if (!this.syncPassword) {
          console.warn('[iCloudSync] encrypted sync file found but no password set')
          return null
        }
        const decrypted = decryptWithPassword(parsed.data as EncryptedPayload, this.syncPassword)
        return JSON.parse(decrypted) as SyncFile
      }

      // Legacy plaintext format (backward compatible)
      if (parsed.deviceId && Array.isArray(parsed.changes)) {
        return parsed as SyncFile
      }

      return null
    } catch {
      return null
    }
  }

  fullSync(): void {
    try {
      this.exportChanges()
      this.importChanges()
      this.lastSyncTime = Date.now()
      this.saveSyncState()
    } catch (error) {
      console.error('[iCloudSync] full sync error:', error)
    }
  }

  syncNow(): void {
    this.exportChanges()
    this.importChanges()
  }

  resolveConflict(localItem: ClipboardItem, remoteItem: ClipboardItem): ClipboardItem {
    if (remoteItem.updated_at > localItem.updated_at) {
      return remoteItem
    }
    return localItem
  }

  private applyChange(change: ChangeRecord): void {
    const { operation, item } = change

    switch (operation) {
      case 'add':
      case 'update': {
        const existing = repository.getItemByHash(item.content_hash)
        if (existing) {
          // Merge: keep favorite/pinned if either side has it
          const merged = {
            ...existing,
            is_favorite: existing.is_favorite || item.is_favorite ? 1 : 0,
            is_pinned: existing.is_pinned || item.is_pinned ? 1 : 0,
            updated_at: Math.max(existing.updated_at, item.updated_at)
          }
          if (
            merged.is_favorite !== existing.is_favorite ||
            merged.is_pinned !== existing.is_pinned ||
            merged.updated_at !== existing.updated_at
          ) {
            repository.deleteItem(existing.id)
            repository.insertItem(merged)
          }
        } else {
          const byId = repository.getItemById(item.id)
          if (byId) {
            const winner = this.resolveConflict(byId, item)
            if (winner.updated_at > byId.updated_at) {
              repository.deleteItem(byId.id)
              repository.insertItem(winner)
            }
          } else {
            repository.insertItem(item)
          }
        }
        break
      }
      case 'delete': {
        repository.deleteItem(item.id)
        break
      }
    }
  }

  private ensureSyncDir(): void {
    if (!existsSync(this.syncDir)) {
      mkdirSync(this.syncDir, { recursive: true })
    }
  }

  private getDeviceId(): string {
    // Store device ID locally (NOT in iCloud Drive) to prevent sync between machines
    const localDir = app.getPath('userData')
    const idFile = join(localDir, '.zpaste-device-id')
    try {
      if (existsSync(idFile)) {
        return readFileSync(idFile, 'utf-8').trim()
      }
    } catch {
      // ignore
    }

    const id = `device_${hostname()}_${Date.now()}_${randomUUID().slice(0, 8)}`
    try {
      writeFileSync(idFile, id, 'utf-8')
    } catch {
      // ignore
    }
    return id
  }

  private loadSyncState(): void {
    try {
      if (existsSync(this.stateFile)) {
        const data: SyncState = JSON.parse(readFileSync(this.stateFile, 'utf-8'))
        this.lastSyncTime = data.lastSyncTime || 0
        this.processedFiles = new Set(data.processedFiles || [])
      }
    } catch {
      // ignore, start fresh
    }
  }

  private saveSyncState(): void {
    try {
      const state: SyncState = {
        lastSyncTime: this.lastSyncTime,
        processedFiles: Array.from(this.processedFiles)
      }
      writeFileSync(this.stateFile, JSON.stringify(state), 'utf-8')
    } catch {
      // ignore
    }
  }

  private cleanupOldSyncFiles(): void {
    try {
      const files = readdirSync(this.syncDir).filter(
        (f) => f.startsWith(`sync_${this.deviceId}_`) && f.endsWith('.json')
      )

      if (files.length > 5) {
        const sorted = files.sort()
        const toDelete = sorted.slice(0, files.length - 5)
        for (const file of toDelete) {
          // Remove from all devices' processed lists by just keeping the file gone
          // Other devices should have already processed these old files
          try {
            const { unlinkSync } = require('fs')
            unlinkSync(join(this.syncDir, file))
          } catch {
            // ignore
          }
        }
      }

      // Clean up stale entries from processedFiles that no longer exist on disk
      const allFiles = new Set(readdirSync(this.syncDir))
      const staleEntries = Array.from(this.processedFiles).filter((f) => !allFiles.has(f))
      for (const entry of staleEntries) {
        this.processedFiles.delete(entry)
      }
    } catch {
      // ignore
    }
  }
}
