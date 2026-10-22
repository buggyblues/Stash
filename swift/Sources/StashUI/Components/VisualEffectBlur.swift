import AppKit
import SwiftUI

/// A view that wraps AppKit's `NSVisualEffectView` to provide macOS vibrancy on older systems.
public struct VisualEffectBlur: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State

    public init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}


/// Apply glass to the navigation shell as a single composited surface.
/// The modifier keeps SwiftUI content inside the system glass rendering hierarchy.
private struct StashGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor))
        } else {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                content.background(VisualEffectBlur(material: .sidebar))
            }
            #else
            content.background(VisualEffectBlur(material: .sidebar))
            #endif
        }
    }
}

public extension View {
    func stashGlassSurface(cornerRadius: CGFloat = 22) -> some View {
        modifier(StashGlassSurfaceModifier(cornerRadius: cornerRadius))
    }
}

/// Native AppKit controls and window chrome must follow the app's appearance override too.
public struct StashWindowAppearance: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    public init() {}

    public func makeNSView(context: Context) -> AppearanceView {
        AppearanceView()
    }

    public func updateNSView(_ view: AppearanceView, context: Context) {
        view.requestedAppearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
    }

    public final class AppearanceView: NSView {
        var requestedAppearance: NSAppearance? {
            didSet { window?.appearance = requestedAppearance }
        }
        public override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.appearance = requestedAppearance
        }
    }
}

/// System button feedback, with the same public API on older macOS versions.
public struct StashToolbarButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .frame(minWidth: 28, minHeight: 28)
            .background(configuration.isPressed ? Color.primary.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}
