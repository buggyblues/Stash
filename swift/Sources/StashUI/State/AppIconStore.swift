import AppKit
import Combine
import Foundation
import StashCore

/// Caches the icons of the applications a clipboard item came from.
@MainActor
public final class AppIconStore: ObservableObject {
    @Published public private(set) var icons: [String: NSImage] = [:]

    private let resolver: AppIconResolver
    private var inFlight: Set<String> = []
    private var unavailable: Set<String> = []

    public init(resolver: AppIconResolver = AppIconResolver()) {
        self.resolver = resolver
    }

    /// The icon for a bundle identifier, loading it on first use.
    public func icon(for bundleId: String) -> NSImage? {
        if let cached = icons[bundleId] { return cached }
        guard !bundleId.isEmpty, !unavailable.contains(bundleId), !inFlight.contains(bundleId) else { return nil }
        inFlight.insert(bundleId)

        let resolver = self.resolver
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let base64 = resolver.icon(for: bundleId)
            DispatchQueue.main.async {
                guard let self else { return }
                self.inFlight.remove(bundleId)
                guard let base64, let data = Data(base64Encoded: base64),
                      let image = NSImage(data: data) else { self.unavailable.insert(bundleId); return }
                self.icons[bundleId] = image
            }
        }
        return nil
    }
}
