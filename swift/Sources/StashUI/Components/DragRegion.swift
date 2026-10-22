import AppKit
import SwiftUI

/// A view that lets the user drag the window by its content.
public struct DragRegion: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = DragRegionView()
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}
}

/// The view that performs the window drag.
final class DragRegionView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
