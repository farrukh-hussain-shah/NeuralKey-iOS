import SwiftUI

/// Setup step 2: Allow Full Access.
///
/// This is the highest-friction moment in any keyboard app, because iOS shows a stark
/// system warning. The screen therefore explains, before the user leaves:
///   • why it is needed (the AI features use the network),
///   • what does and does not leave the device,
///   • that the system warning is expected.
/// Full Access stays optional — the keyboard works without it — so "Not now" is always
/// available (App Review Guideline 4.4.1).
struct FullAccessStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private var isGranted: Bool { viewModel.status.fullAccess == .granted }

    private static let hintText: AttributedString = {
        let markdown = "In Settings, tap **Keyboards › Allow Full Access**. iOS shows a standard warning for every keyboard. Tap **Allow**. [Privacy Policy](\(AppLinks.privacyPolicy.absoluteString))"
        if let attributed = try? AttributedString(markdown: markdown) {
            return attributed
        }
        return AttributedString("In Settings, tap Keyboards › Allow Full Access. iOS shows a standard warning for every keyboard. Tap Allow.")
    }()

    var body: some View {
        OnboardingScaffold(
            topBar: OnboardingTopBar(
                step: .fullAccess,
                onBack: { viewModel.goBack() },
                onHelp: { viewModel.showHelp() }
            ),
            heroSize: .compact,
            hero: {
                SettingsKeyboardsIllustration(
                    focus: .fullAccess,
                    isKeyboardOn: true,
                    isFullAccessOn: isGranted,
                    isCompact: true
                )
            },
            content: {
                VStack(spacing: NKSpacing.m) {
                    NKTwoToneTitle(line1: "Turn on", line2: "Full Access")

                    Text("Improve, Translate and Tone need the internet. iOS only lets a keyboard go online with Full Access.")
                        .nkFont(.body)
                        .foregroundColor(NKColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if isGranted {
                        NKStatusBanner(
                            kind: .success,
                            title: "Full Access is on",
                            message: "AI features are ready to use."
                        )
                    }

                    VStack(alignment: .leading, spacing: NKSpacing.m) {
                        NKInfoRow(
                            systemImage: "lock.shield",
                            title: "Your typing stays on your iPhone",
                            message: "Only text you choose to rewrite is sent."
                        )
                        NKInfoRow(
                            systemImage: "key",
                            title: "Passwords are never seen",
                            message: "iOS uses its own keyboard for passwords."
                        )
                        NKInfoRow(
                            systemImage: "switch.2",
                            title: "You stay in control",
                            message: "Turn it off any time. Typing keeps working."
                        )
                    }
                    .nkCard()

                    // Prepares the user for the system alert so it does not scare them off,
                    // and keeps the privacy policy one tap away at the moment of doubt.
                    Text(Self.hintText)
                        .nkFont(.footnote)
                        .foregroundColor(NKColor.textSecondary)
                        .tint(NKColor.brandText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            },
            footer: {
                if isGranted {
                    OnboardingActions(primaryTitle: "Continue", primaryAction: { viewModel.advance() })
                } else if viewModel.hasOpenedSettings {
                    // We cannot confirm Full Access until the keyboard is opened, which
                    // happens on the next step — so let the user move on.
                    OnboardingActions(
                        primaryTitle: "Continue",
                        primaryAction: { viewModel.advance() },
                        secondaryTitle: "Open Settings again",
                        secondaryAction: { viewModel.openSettings() }
                    )
                } else {
                    OnboardingActions(
                        primaryTitle: "Open Settings",
                        primarySystemImage: "arrow.up.forward.app",
                        primaryAction: { viewModel.openSettings() },
                        secondaryTitle: "Not now",
                        secondaryAction: { viewModel.skipFullAccess() }
                    )
                }
            }
        )
    }
}
