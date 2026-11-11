import SwiftUI

/// Final screen: confirms what is set up, flags what is not, and sets expectations about
/// where a third-party keyboard can and cannot appear.
struct OnboardingCompleteView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private var isFullAccessOn: Bool { viewModel.status.fullAccess == .granted }

    var body: some View {
        OnboardingScaffold(
            hero: {
                SetupCompleteIllustration()
            },
            content: {
                VStack(spacing: NKSpacing.m) {
                    NKTwoToneTitle(line1: "You're", line2: "all set")

                    Text("Neural Key is ready wherever you type.")
                        .nkFont(.body)
                        .foregroundColor(NKColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: NKSpacing.m) {
                        NKInfoRow(
                            systemImage: "checkmark",
                            title: "Keyboard added",
                            message: "Touch and hold the globe key to switch to Neural Key in any app.",
                            tint: NKColor.success
                        )

                        if isFullAccessOn {
                            NKInfoRow(
                                systemImage: "checkmark",
                                title: "AI features on",
                                message: "Improve, Translate and Tone are ready.",
                                tint: NKColor.success
                            )
                        } else {
                            NKInfoRow(
                                systemImage: "exclamationmark",
                                title: "AI features are off",
                                message: "Typing works now. Turn on Full Access when you want Improve, Translate and Tone.",
                                tint: NKColor.warning
                            )
                        }

                        NKInfoRow(
                            systemImage: "info",
                            title: "Good to know",
                            message: "Password fields and a few apps, such as some banking apps, always use the iOS keyboard."
                        )
                    }
                    .nkCard()
                }
            },
            footer: {
                if isFullAccessOn {
                    OnboardingActions(primaryTitle: "Start Using Neural Key", primaryAction: { viewModel.finish() })
                } else {
                    OnboardingActions(
                        primaryTitle: "Start Using Neural Key",
                        primaryAction: { viewModel.finish() },
                        secondaryTitle: "Turn on Full Access",
                        secondaryAction: { viewModel.openSettings() }
                    )
                }
            }
        )
    }
}
