import SwiftUI

/// Setup step 1: add Neural Key to the list of keyboards in Settings.
///
/// States: waiting (instructions) → not detected (user came back, still off) → added.
struct AddKeyboardStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private var isAdded: Bool { viewModel.status.isKeyboardAdded }

    var body: some View {
        OnboardingScaffold(
            topBar: OnboardingTopBar(
                step: .addKeyboard,
                onBack: { viewModel.goBack() },
                onHelp: { viewModel.showHelp() }
            ),
            hero: {
                SettingsKeyboardsIllustration(focus: .keyboard, isKeyboardOn: isAdded, isFullAccessOn: false)
            },
            content: {
                VStack(spacing: NKSpacing.m) {
                    NKTwoToneTitle(line1: "Add", line2: "Neural Key")

                    Text("iOS asks you to switch on new keyboards in Settings. It takes about ten seconds.")
                        .nkFont(.body)
                        .foregroundColor(NKColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if isAdded {
                        NKStatusBanner(
                            kind: .success,
                            title: "Neural Key is added",
                            message: "Nice. One more switch to unlock the AI features."
                        )
                    } else {
                        VStack(alignment: .leading, spacing: NKSpacing.s) {
                            NKNumberedStep(number: 1, text: "Tap **Open Settings** below")
                            NKNumberedStep(number: 2, text: "Tap **Keyboards**")
                            NKNumberedStep(number: 3, text: "Turn on **Neural Key**, then come back here")
                        }
                        .nkCard()

                        if viewModel.showsKeyboardNotDetected {
                            NKStatusBanner(
                                kind: .warning,
                                title: "We can't see Neural Key yet",
                                message: "Check that the Neural Key switch is on. Can't find it? Tap Help for another way."
                            )
                        }
                    }
                }
            },
            footer: {
                if isAdded {
                    OnboardingActions(primaryTitle: "Continue", primaryAction: { viewModel.advance() })
                } else if viewModel.showsKeyboardNotDetected {
                    OnboardingActions(
                        primaryTitle: "Open Settings",
                        primarySystemImage: "arrow.up.forward.app",
                        primaryAction: { viewModel.openSettings() },
                        secondaryTitle: "I've already added it",
                        secondaryAction: { viewModel.advance() }
                    )
                } else {
                    OnboardingActions(
                        primaryTitle: "Open Settings",
                        primarySystemImage: "arrow.up.forward.app",
                        primaryAction: { viewModel.openSettings() }
                    )
                }
            }
        )
    }
}
