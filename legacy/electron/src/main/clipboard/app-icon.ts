import { execSync } from 'child_process'
import { existsSync, mkdirSync, readFileSync } from 'fs'
import { join } from 'path'
import { app } from 'electron'

const iconCache = new Map<string, string | null>()

function getIconDir(): string {
  const dir = join(app.getPath('userData'), 'app-icons')
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  return dir
}

export async function getAppIcon(bundleId: string): Promise<string | null> {
  if (!bundleId) return null

  // Check memory cache
  if (iconCache.has(bundleId)) return iconCache.get(bundleId)!

  // Check disk cache
  const iconDir = getIconDir()
  const cachedPath = join(iconDir, `${bundleId}.png`)
  if (existsSync(cachedPath)) {
    const buf = readFileSync(cachedPath)
    if (buf.length > 0) {
      const base64 = buf.toString('base64')
      iconCache.set(bundleId, base64)
      return base64
    }
  }

  try {
    // Find app path via mdfind
    const appPath = execSync(
      `mdfind "kMDItemCFBundleIdentifier == '${bundleId}'" | head -1`,
      { encoding: 'utf-8', timeout: 3000 }
    ).trim()

    if (!appPath) {
      iconCache.set(bundleId, null)
      return null
    }

    // Read CFBundleIconFile from Info.plist
    let icnsPath: string | null = null

    try {
      const iconFile = execSync(
        `defaults read "${appPath}/Contents/Info" CFBundleIconFile 2>/dev/null || echo ""`,
        { encoding: 'utf-8', timeout: 3000 }
      ).trim()

      if (iconFile) {
        const icnsName = iconFile.endsWith('.icns') ? iconFile : `${iconFile}.icns`
        const candidate = join(appPath, 'Contents/Resources', icnsName)
        if (existsSync(candidate)) icnsPath = candidate
      }
    } catch {
      // continue
    }

    // Fallback: try AppIcon.icns
    if (!icnsPath) {
      const candidate = join(appPath, 'Contents/Resources/AppIcon.icns')
      if (existsSync(candidate)) icnsPath = candidate
    }

    if (!icnsPath) {
      iconCache.set(bundleId, null)
      return null
    }

    // Use macOS sips to convert .icns -> .png (nativeImage.createFromPath is unreliable for icns)
    try {
      execSync(
        `sips -s format png -z 32 32 "${icnsPath}" --out "${cachedPath}"`,
        { encoding: 'utf-8', timeout: 5000, stdio: ['pipe', 'pipe', 'pipe'] }
      )

      if (existsSync(cachedPath)) {
        const buf = readFileSync(cachedPath)
        if (buf.length > 0) {
          const base64 = buf.toString('base64')
          iconCache.set(bundleId, base64)
          return base64
        }
      }
    } catch {
      // sips failed
    }

    iconCache.set(bundleId, null)
    return null
  } catch {
    iconCache.set(bundleId, null)
    return null
  }
}
