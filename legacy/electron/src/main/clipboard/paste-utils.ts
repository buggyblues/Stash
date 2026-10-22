import { clipboard, nativeImage } from 'electron'
import { readFileSync, existsSync } from 'fs'

/**
 * Write a clipboard item's content to the system clipboard,
 * handling images (base64 / file path) and text appropriately.
 */
export function writeItemToClipboard(content: string, contentType: string): void {
  if (contentType === 'image') {
    const isFilePath = content.startsWith('/') || content.startsWith('~')
    let image: Electron.NativeImage

    if (isFilePath && existsSync(content)) {
      const buffer = readFileSync(content)
      image = nativeImage.createFromBuffer(buffer)
    } else {
      // base64-encoded PNG
      const buffer = Buffer.from(content, 'base64')
      image = nativeImage.createFromBuffer(buffer)
    }

    if (!image.isEmpty()) {
      clipboard.writeImage(image)
      return
    }
  }

  // Fallback: write as text for all other types
  clipboard.writeText(content)
}
