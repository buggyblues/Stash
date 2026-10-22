import AppKit
import CryptoKit
import Foundation
import StashCore

/// Watches the system pasteboard and records every new copy.
///
/// Text and images are captured separately, mirroring the behaviour of the
/// previous implementation: an image is only inspected when the text content
/// did not just change.
public final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount = -1
    private let pasteboard: NSPasteboard
    private var polling = false

    private let repository: Repository
    private var onNewItem: ((ClipboardItem) -> Void)?

    /// Images larger than this are stored as a file instead of base64.
    private static let maxImageBase64Size = 5 * 1024 * 1024

    public init(repository: Repository, pasteboard: NSPasteboard = .general) {
        self.repository = repository
        self.pasteboard = pasteboard
    }

    /// Called whenever a new (or refreshed) clipboard item was recorded.
    public var onNewItemHandler: ((ClipboardItem) -> Void)? {
        get { onNewItem }
        set { onNewItem = newValue }
    }

    public func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    func poll() {
        guard !polling, pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        polling = true
        defer { polling = false }

        let textChanged = checkText()
        if !textChanged {
            checkImage()
        }
    }

    // MARK: - Text

    private func checkText() -> Bool {
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: Self.trimCharacters).isEmpty
        else { return false }

        let hash = Self.sha256(Data(text.utf8))

        if let existing = try? repository.getItemByHash(hash) {
            try? repository.touchItem(existing.id)
            if let refreshed = try? repository.getItemById(existing.id) { onNewItem?(refreshed) }
            return true
        }

        let detection = ContentDetector.detect(text)
        let preview = String(text.prefix(200))
        let item = ClipboardItem(
            id: Self.makeId(),
            content: text,
            contentType: detection.type.rawValue,
            contentHash: hash,
            preview: preview,
            metadata: detection.metadata.map { Self.encodeMetadata($0) },
            isFavorite: false,
            isPinned: false,
            sourceApp: currentSourceApp(),
            tags: nil,
            title: nil,
            categoryId: nil,
            createdAt: Self.now(),
            updatedAt: Self.now(),
            useCount: 0
        )

        do {
            try repository.insertItem(item)
            onNewItem?(item)
        } catch { NSLog("[Clipboard] capture failed: \(error)") }
        return true
    }

    // MARK: - Images

    private func checkImage() {
        guard let raw = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
              !raw.isEmpty
        else { return }

        // The previous build always stored PNG, so the payload is normalised
        // before it is hashed and written.
        let (data, size) = Self.normalizedPNG(from: raw)
        let hash = Self.sha256(data)

        if let existing = try? repository.getItemByHash(hash) {
            try? repository.touchItem(existing.id)
            if let refreshed = try? repository.getItemById(existing.id) { onNewItem?(refreshed) }
            return
        }

        let content: String
        if data.count > Self.maxImageBase64Size {
            let directory = AppPaths.imagesDirectory
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = directory.appendingPathComponent("\(Self.makeId()).png")
            do {
                try data.write(to: fileURL)
                content = fileURL.path
            } catch {
                content = data.base64EncodedString()
            }
        } else {
            content = data.base64EncodedString()
        }

        let item = ClipboardItem(
            id: Self.makeId(),
            content: content,
            contentType: ContentType.image.rawValue,
            contentHash: hash,
            preview: size.map { "Image \($0.width)x\($0.height)" },
            metadata: size.map { Self.encodeImageMetadata(width: $0.width, height: $0.height) },
            isFavorite: false,
            isPinned: false,
            sourceApp: currentSourceApp(),
            tags: nil,
            title: nil,
            categoryId: nil,
            createdAt: Self.now(),
            updatedAt: Self.now(),
            useCount: 0
        )

        do {
            try repository.insertItem(item)
            onNewItem?(item)
        } catch { NSLog("[Clipboard] capture failed: \(error)") }
    }

    // MARK: - Helpers

    /// The application that was frontmost when the copy happened.
    private func currentSourceApp() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let bundleId = app.bundleIdentifier ?? ""
        guard !bundleId.isEmpty, bundleId != "com.apple.loginwindow" else { return nil }
        let name = app.localizedName ?? ""
        guard !name.isEmpty else { return nil }
        return SourceApp(name: name, bundleId: bundleId).encoded()
    }

    private static func encodeMetadata(_ values: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: values),
              let text = String(data: data, encoding: .utf8)
        else { return "{}" }
        return text
    }

    /// Encodes the image dimensions as numbers, like the previous build.
    private static func encodeImageMetadata(width: Int, height: Int) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: ["width": width, "height": height]
        ), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    /// Converts any pasteboard image into PNG and reports its pixel size.
    static func normalizedPNG(from raw: Data) -> (data: Data, size: (width: Int, height: Int)?) {
        guard let image = NSImage(data: raw),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return (raw, imageSize(from: raw))
        }
        let size = (width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            return (raw, size)
        }
        return (png, size)
    }

    /// The characters that are stripped by the JavaScript `String.trim()`.
    static let trimCharacters = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: "\u{FEFF}"))

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func makeId() -> String {
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-")
        return String((0..<21).map { _ in alphabet.randomElement()! })
    }

    static func now() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// Reads the pixel dimensions out of a PNG file.
    static func imageSize(from data: Data) -> (width: Int, height: Int)? {
        guard data.count > 24 else { return nil }
        let bytes = [UInt8](data.prefix(24))
        // PNG signature followed by the IHDR chunk.
        guard bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 else {
            return nil
        }
        let width = Int(bytes[16]) << 24 | Int(bytes[17]) << 16 | Int(bytes[18]) << 8 | Int(bytes[19])
        let height = Int(bytes[20]) << 24 | Int(bytes[21]) << 16 | Int(bytes[22]) << 8 | Int(bytes[23])
        return (width, height)
    }
}
