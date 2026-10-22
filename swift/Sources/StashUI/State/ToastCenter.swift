import Combine
import Foundation
import StashCore

/// A short lived notification shown at the bottom of the window.
public struct ToastMessage: Equatable, Identifiable {
    public let id = UUID()
    public var text: String

    public init(text: String) {
        self.text = text
    }
}

/// The toast host. Only one message is visible at a time, matching the
/// previous implementation.
@MainActor
public final class ToastCenter: ObservableObject {
    @Published public private(set) var message: ToastMessage?

    private var dismissTask: Task<Void, Never>?

    public nonisolated init() {}

    /// Shows a message and hides it after two seconds.
    public func show(_ text: String) {
        dismissTask?.cancel()
        message = ToastMessage(text: text)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }

    public func dismiss() {
        dismissTask?.cancel()
        message = nil
    }
}

/// Convenience access to the translation helper.
public enum L10n {
    public static func t(_ key: String, _ params: [String: String] = [:]) -> String {
        Localization.shared.t(key, params)
    }
}
