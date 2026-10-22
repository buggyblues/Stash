import AppKit
import SwiftUI

public extension Notification.Name {
    static let stashZoom = Notification.Name("com.zpaste.app.zoom")
}

public struct ZoomContainer<Content: View>: View {
    let identifier: NSUserInterfaceItemIdentifier
    let content: Content
    @State private var zoom: CGFloat = 1

    public init(identifier: NSUserInterfaceItemIdentifier, @ViewBuilder content: () -> Content) {
        self.identifier = identifier
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            content
                .frame(width: geometry.size.width / zoom, height: geometry.size.height / zoom)
                .scaleEffect(zoom, anchor: .topLeading)
        }
        .clipped()
        .onReceive(NotificationCenter.default.publisher(for: .stashZoom)) { event in
            guard event.object as? NSUserInterfaceItemIdentifier == identifier,
                  let direction = event.userInfo?["direction"] as? Int else { return }
            zoom = direction == 0 ? 1 : min(max(zoom + CGFloat(direction) * 0.1, 0.7), 1.5)
        }
    }
}
