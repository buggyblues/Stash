import AppKit
import Foundation
import SwiftUI

/// A process wide cache for decoded clipboard images.
///
/// The panel and the widget can show the same image at the same time. Decoding
/// it once and sharing the result avoids duplicate work and keeps the SwiftUI
/// updates of the two windows apart.
final class ClipboardImageCache {
    static let shared = ClipboardImageCache()

    private let images = NSCache<NSString, NSImage>()
    private init() { images.countLimit = 128; images.totalCostLimit = 64 * 1024 * 1024 }
    private let lock = NSLock()

    /// The cached image for a content hash, if it was decoded before.
    func image(for key: String) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        return images.object(forKey: key as NSString)
    }

    /// Decodes the image unless it is already cached.
    func image(for key: String, content: String) -> NSImage? {
        lock.lock()
        if let cached = images.object(forKey: key as NSString) {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let data = Self.decode(content), let image = NSImage(data: data) else { return nil }

        lock.lock()
        images.setObject(image, forKey: key as NSString, cost: max(data.count, Int(image.size.width * image.size.height * 4)))
        lock.unlock()
        return image
    }

    /// Decodes base64 payloads and file paths.
    static func decode(_ content: String) -> Data? {
        if content.hasPrefix("/") || content.hasPrefix("~") {
            let path = content.hasPrefix("~")
                ? (content as NSString).expandingTildeInPath
                : content
            return try? Data(contentsOf: URL(fileURLWithPath: path))
        }
        return Data(base64Encoded: content)
    }
}

/// NSImage is immutable after construction in this cache; older deployment
/// targets do not declare its later Sendable conformance.
private struct LoadedClipboardImage: @unchecked Sendable {
    let image: NSImage?
}

/// Loads an image for a preview.
///
/// The image is decoded off the main thread and published on the main queue.
/// Using an observable object instead of `@State` avoids mutating the view
/// state while SwiftUI is updating the view graph.
@MainActor
public final class ImageLoader: ObservableObject {
    @Published public private(set) var image: NSImage?

    private var task: Task<Void, Never>?
    private var currentKey: String?

    deinit {
        task?.cancel()
    }

    /// Loads an image from a base64 payload or from a file path.
    public func load(content: String, key: String) {
        guard currentKey != key || image == nil else { return }
        currentKey = key
        task?.cancel()
        image = nil
        guard !content.isEmpty else { return }
        if let cached = ClipboardImageCache.shared.image(for: key) {
            image = cached
            return
        }
        task = Task { [weak self] in
            let loaded = await Task.detached(priority: .utility) {
                LoadedClipboardImage(image: ClipboardImageCache.shared.image(for: key, content: content))
            }.value
            guard !Task.isCancelled, self?.currentKey == key else { return }
            self?.image = loaded.image
        }
    }
}

/// Holds lazily loaded text content outside of the view state.
public final class ContentLoader: ObservableObject {
    @Published public private(set) var content: String?

    /// Publishes the content on the main thread.
    public func set(_ value: String?) {
        content = value
    }
}
