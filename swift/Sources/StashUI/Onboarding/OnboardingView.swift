import StashCore
import SwiftUI

/// The onboarding flow shown on the first launch and from the help button.
public struct OnboardingView: View {
    @ObservedObject public var settings: SettingsStore
    private var theme: StashTheme {
        StashTheme(resolved: settings.resolvedTheme, accentHex: settings.accentColor)
    }
    /// `true` when the flow is opened from the help button instead of the
    /// first launch. Nothing is persisted in that case.
    public var isRevisit: Bool
    var onComplete: () -> Void
    /// Called when the last step is confirmed. The iCloud choice is applied
    /// here and not before.
    var onFinished: ((Bool) -> Void)?
    /// Called when the flow is skipped.
    var onSkipped: (() -> Void)?

    @ObservedObject private var localization = Localization.shared
    @State private var currentStep = 0
    @State private var syncChoice = false
    @State private var viewportSize: CGSize = .zero

    public init(
        settings: SettingsStore,
        isRevisit: Bool = false,
        onComplete: @escaping () -> Void = {},
        onFinished: ((Bool) -> Void)? = nil,
        onSkipped: (() -> Void)? = nil
    ) {
        self.settings = settings
        self.isRevisit = isRevisit
        self.onComplete = onComplete
        self.onFinished = onFinished
        self.onSkipped = onSkipped
    }

    /// The steps of the flow, in order.
    private var steps: [OnboardingStep] {
        [
            .welcome,
            .smartClipboard,
            .efficiency,
            .shortcuts,
            .privacy,
            .ready
        ]
    }

    private var isLastStep: Bool { currentStep == steps.count - 1 }
    private var showSidebar: Bool { viewportSize.width >= 768 && viewportSize.height >= 560 }

    public var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                sidebar
            }

            VStack(spacing: 0) {
                header
                content
                footer
            }
            .background(theme.background)
        }
        .stashGlassSurface()
        .background(StashWindowAppearance().frame(width: 0, height: 0))
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .tint(theme.accentColor)
        .background(
            GeometryReader { proxy in
                Color.clear.onAppear { viewportSize = proxy.size }.onChange(of: proxy.size) { newValue in
                    viewportSize = newValue
                }
            }
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STASH")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.6)
                .foregroundColor(theme.mutedForeground)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if !showSidebar {
                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 16))
                        .foregroundColor(theme.accentColor)
                }
                Text(L10n.t(steps[currentStep].titleKey))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(theme.foreground)
                Spacer()
                Text("\(currentStep + 1) / \(steps.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.mutedForeground)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(theme.card.opacity(0.8))
                    )
            }

            Text(L10n.t(steps[currentStep].descriptionKey))
                .font(.system(size: 12))
                .foregroundColor(theme.mutedForeground)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.card.opacity(0.8))
                    .frame(width: 48, height: 48)
                Image(systemName: steps[currentStep].icon)
                    .font(.system(size: 20))
                    .foregroundColor(theme.accentColor)
            }
            .padding(.bottom, 8)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 7) {
                    Circle()
                        .fill(index == currentStep ? theme.accentColor : theme.border)
                        .frame(width: 5, height: 5)
                    Text(L10n.t(step.titleKey))
                        .font(.system(size: 11, weight: index == currentStep ? .medium : .regular))
                        .foregroundColor(index == currentStep
                                         ? theme.foreground
                                         : theme.mutedForeground)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(index == currentStep ? theme.accentColor.opacity(0.12) : Color.clear)
                )
            }

            Spacer()

            Text(L10n.t("onboarding.step7.hint"))
                .font(.system(size: 10))
                .foregroundColor(theme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(width: 160)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch currentStep {
                case 0:
                    featureCard(icon: "tray.full", titleKey: "onboarding.step1.feature1.title", descriptionKey: "onboarding.step1.feature1.desc")
                    featureCard(icon: "bolt.fill", titleKey: "onboarding.step1.feature2.title", descriptionKey: "onboarding.step1.feature2.desc")
                case 1:
                    featureCard(icon: "square.grid.2x2", titleKey: "onboarding.step2.feature1.title", descriptionKey: "onboarding.step2.feature1.desc")
                    featureCard(icon: "chevron.left.forwardslash.chevron.right", titleKey: "onboarding.step2.feature2.title", descriptionKey: "onboarding.step2.feature2.desc")
                    featureCard(icon: "eye", titleKey: "onboarding.step2.feature3.title", descriptionKey: "onboarding.step2.feature3.desc")
                    featureCard(icon: "textformat", titleKey: "onboarding.step2.feature4.title", descriptionKey: "onboarding.step2.feature4.desc")
                case 2:
                    featureCard(icon: "doc.on.clipboard", titleKey: "onboarding.step3.feature1.title", descriptionKey: "onboarding.step3.feature1.desc")
                    featureCard(icon: "tag", titleKey: "onboarding.step3.feature2.title", descriptionKey: "onboarding.step3.feature2.desc")
                    featureCard(icon: "macwindow", titleKey: "onboarding.step3.feature3.title", descriptionKey: "onboarding.step3.feature3.desc")
                    featureCard(icon: "list.number", titleKey: "onboarding.step3.feature4.title", descriptionKey: "onboarding.step3.feature4.desc")
                case 3:
                    shortcutsStep
                case 4:
                    privacyStep
                default:
                    readyStep
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func featureCard(icon: String, titleKey: String, descriptionKey: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(theme.accentColor)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(theme.accentColor.opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t(titleKey))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.foreground)
                Text(L10n.t(descriptionKey))
                    .font(.system(size: 11))
                    .foregroundColor(theme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(theme.card.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(theme.border.opacity(0.7), lineWidth: 1)
        )
    }

    private var shortcutsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                keycap("⇧")
                keycap("⌘")
                keycap("V")
                Text(L10n.t("onboarding.step5.shortcutHint"))
                    .font(.system(size: 11))
                    .foregroundColor(theme.mutedForeground)
                    .padding(.leading, 6)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(theme.card.opacity(0.85))
            )

            Text(L10n.t("onboarding.step5.autoPaste"))
                .font(.system(size: 11))
                .foregroundColor(theme.mutedForeground)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("onboarding.step5.moreShortcuts"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.foreground)

                shortcutRow(L10n.t("onboarding.step5.seqPaste"), L10n.t("onboarding.step5.seqPasteDesc"))
                shortcutRow(L10n.t("onboarding.step5.batchPaste"), L10n.t("onboarding.step5.batchPasteDesc"))
                shortcutRow(L10n.t("onboarding.step5.numbers"), L10n.t("onboarding.step5.numbersDesc"))
                shortcutRow(L10n.t("onboarding.step5.widget"), L10n.t("onboarding.step5.widgetDesc"))
                shortcutRow(L10n.t("onboarding.step5.layout"), L10n.t("onboarding.step5.layoutDesc"))
                shortcutRow(L10n.t("onboarding.step5.closePanel"), L10n.t("onboarding.step5.closePanelDesc"))
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(theme.card.opacity(0.85))
            )
        }
    }

    private func keycap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(theme.foreground)
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.muted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
    }

    private func shortcutRow(_ shortcut: String, _ description: String) -> some View {
        HStack(spacing: 10) {
            Text(shortcut)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(theme.foreground)
                .frame(width: 46, alignment: .leading)
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(theme.mutedForeground)
            Spacer()
        }
    }

    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureCard(icon: "internaldrive", titleKey: "onboarding.step6.storage.title", descriptionKey: "onboarding.step6.storage.desc")
            featureCard(icon: "icloud", titleKey: "onboarding.step6.sync.title", descriptionKey: "onboarding.step6.sync.desc")

            HStack {
                Text(L10n.t("onboarding.step6.sync.title"))
                    .font(.system(size: 11))
                    .foregroundColor(theme.mutedForeground)
                Spacer()
                Toggle("", isOn: $syncChoice)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
            }

            AccessibilityPermissionRow(theme: theme)
        }
    }

    private var readyStep: some View {
        VStack(spacing: 12) {
            AppLogoView(size: 72)
            Text(L10n.t("onboarding.step7.ready"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.foreground)
            Text(L10n.t("onboarding.step7.freeInfo"))
                .font(.system(size: 11))
                .foregroundColor(theme.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep
                              ? theme.accentColor
                              : (index < currentStep ? theme.accentColor.opacity(0.4) : theme.border))
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            if !isLastStep {
                Button(L10n.t("onboarding.skip")) {
                    onSkipped?()
                    finish()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(theme.mutedForeground)
            }

            Button(isLastStep ? L10n.t("onboarding.start") : L10n.t("onboarding.next")) {
                advance()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(theme.accentForeground)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(theme.accentColor)
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Navigation

    private func advance() {
        if isLastStep {
            // The sync choice is only applied when the last step is confirmed.
            onFinished?(syncChoice)
            finish()
        } else {
            currentStep += 1
        }
    }

    private func finish() {
        onComplete()
    }
}

/// A single step of the onboarding flow.
public struct OnboardingStep {
    public let titleKey: String
    public let descriptionKey: String
    public let icon: String

    public init(titleKey: String, descriptionKey: String, icon: String) {
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.icon = icon
    }

    static let welcome = OnboardingStep(
        titleKey: "onboarding.step1.title",
        descriptionKey: "onboarding.step1.description",
        icon: "rocket"
    )
    static let smartClipboard = OnboardingStep(
        titleKey: "onboarding.step2.title",
        descriptionKey: "onboarding.step2.description",
        icon: "sparkles"
    )
    static let efficiency = OnboardingStep(
        titleKey: "onboarding.step3.title",
        descriptionKey: "onboarding.step3.description",
        icon: "bolt"
    )
    static let shortcuts = OnboardingStep(
        titleKey: "onboarding.step5.title",
        descriptionKey: "onboarding.step5.description",
        icon: "keyboard"
    )
    static let privacy = OnboardingStep(
        titleKey: "onboarding.step6.title",
        descriptionKey: "onboarding.step6.description",
        icon: "lock"
    )
    static let ready = OnboardingStep(
        titleKey: "onboarding.step7.title",
        descriptionKey: "onboarding.step7.description",
        icon: "sparkles"
    )
}
