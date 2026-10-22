import AppKit
import StashCore

/// The paste queue used by the sequence and batch paste shortcuts.
public final class SequenceQueueManager {
    public struct QueueItem: Equatable {
        public var id: String
        public var content: String
        public var contentType: String

        public init(id: String, content: String, contentType: String) {
            self.id = id
            self.content = content
            self.contentType = contentType
        }
    }

    private let repository: Repository
    private let writeItem: (String, String) -> Bool
    private let writeText: (String) -> Void
    private let simulatePaste: () -> Void
    private let canPaste: () -> Bool
    private var isPasting = false
    private var queue: [QueueItem] = []
    private var index = 0
    private var batchSeparator = "\n"

    /// Called when the queue changed.
    public var onUpdated: ((Int) -> Void)?
    /// Called after an item was pasted.
    public var onPasted: ((Int, Int) -> Void)?
    /// Called after the whole queue was pasted at once.
    public var onBatchPasted: ((Int) -> Void)?
    /// Called when the queue was cleared.
    public var onFinished: (() -> Void)?

    public init(repository: Repository,
                writeItem: @escaping (String, String) -> Bool = { PasteService.shared.write(content: $0, contentType: $1) },
                writeText: @escaping (String) -> Void = { PasteService.shared.write(text: $0) },
                simulatePaste: @escaping () -> Void = { PasteService.shared.simulatePaste() },
                canPaste: @escaping () -> Bool = { AXIsProcessTrusted() }) {
        self.repository = repository
        self.writeItem = writeItem
        self.writeText = writeText
        self.simulatePaste = simulatePaste
        self.canPaste = canPaste
    }

    public func setBatchSeparator(_ separator: String) {
        batchSeparator = separator
    }

    public var count: Int { queue.count }
    public var items: [QueueItem] { queue }

    public func add(id: String) {
        guard let resolved = resolve(id), !queue.contains(where: { $0.id == resolved.id }) else { return }
        queue.append(resolved)
        onUpdated?(queue.count)
    }

    public func addMultiple(ids: [String]) {
        var existing = Set(queue.map(\.id))
        let additions = ids
            .compactMap(resolve)
            .filter { existing.insert($0.id).inserted }
        guard !additions.isEmpty else { return }
        queue.append(contentsOf: additions)
        onUpdated?(queue.count)
    }

    public func clear() {
        queue.removeAll()
        index = 0
        onUpdated?(0)
    }

    /// Pastes the next queued item.
    public func pasteNext() {
        guard !isPasting, canPaste() else { return }
        guard !queue.isEmpty, index < queue.count else {
            clear()
            onFinished?()
            return
        }

        let item = queue[index]
        guard writeItem(item.content, item.contentType) else { return }
        isPasting = true
        index += 1
        onPasted?(index, queue.count)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
            self.isPasting = false
        }

        if index >= queue.count {
            clear()
            onFinished?()
        }
    }

    /// Pastes every queued item at once.
    public func pasteAll() {
        guard !isPasting, canPaste(), !queue.isEmpty else { return }
        isPasting = true
        let combined = queue.map(\.content).joined(separator: batchSeparator)
        writeText(combined)
        onBatchPasted?(queue.count)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
            self.isPasting = false
        }

        clear()
        onFinished?()
    }

    private func resolve(_ id: String) -> QueueItem? {
        guard let item = try? repository.getItemById(id) else { return nil }
        return QueueItem(id: item.id, content: item.content, contentType: item.contentType)
    }
}
