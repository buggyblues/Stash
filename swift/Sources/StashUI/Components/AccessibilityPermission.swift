import AppKit
import ApplicationServices
import Foundation
import SwiftUI

/// The state of the "Accessibility" permission Stash needs to paste content
/// back into the application the user is working in.
public enum AccessibilityPermission {
    /// Whether the app is trusted to control the computer.
    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Asks macOS to show the permission prompt.
    public static func prompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Opens the accessibility pane of the system settings.
    public static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url {
            NSWorkspace.shared.open(url)
        }
    }
}

/// A row that shows the accessibility permission and offers a shortcut to the
/// system settings.
public struct AccessibilityPermissionRow: View {
    public let theme: StashTheme
    @State private var isTrusted = AccessibilityPermission.isTrusted

    public init(theme: StashTheme) {
        self.theme = theme
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundColor(isTrusted ? .green : .yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("onboarding.step6.permission.title"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.foreground)
                Text(isTrusted
                     ? L10n.t("onboarding.step6.permission.granted")
                     : L10n.t("onboarding.step6.permission.desc"))
                    .font(.system(size: 10))
                    .foregroundColor(theme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if !isTrusted {
                Button {
                    AccessibilityPermission.openSettings()
                } label: {
                    Text(L10n.t("onboarding.step6.permission.button"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.cardElevated.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.border.opacity(0.6), lineWidth: 0.8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.subtleSpecularHighlight, lineWidth: 0.5)
        )
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isTrusted = AccessibilityPermission.isTrusted
        }
    }
}
