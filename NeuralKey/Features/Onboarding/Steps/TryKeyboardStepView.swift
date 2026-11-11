import SwiftUI

/// Setup step 3: switch to Neural Key and type.
///
/// Doubles as verification. When the keyboard appears it reports in, which is the only
/// way the app can confirm Full Access. Detection is a bonus, not a gate: the user can
/// always continue.
struct TryKeyboardStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @State private var sampleText = ""
    @FocusState private var isFieldFocused: Bool

    private var isActive: Bool { viewModel.isKeyboardActiveNow }
    private var isFullAccessOn: Bool { viewModel.status.fullAccess == .granted }

    var body: some View {
        OnboardingScaffold(
            topBar: OnboardingTopBar(
                step: .tryKeyboard,
                onBack: {
                    isFieldFocused = false
                    viewModel.goBack()
                },
                onHelp: {
                    isFieldFocused = false
                    viewModel.showHelp()
                }
            ),
            isHeroCollapsed: isFieldFocused,
            hero: {
                KeyboardSwitcherIllustration()
            },
            content: {
                VStack(spacing: NKSpacing.m) {
                    NKTwoToneTitle(line1: "Switch to", line2: "Neural Key")

                    Text("Tap the box below, then touch and hold \(Image(systemName: "globe")) on your keyboard and choose **Neural Key**.")
                        .nkFont(.body)
                        .foregroundColor(NKColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    testField

                    if isActive {
                        NKStatusBanner(
                            kind: .success,
                            title: "Neural Key is active",
                            message: isFullAccessOn
                                ? "You're typing with Neural Key. AI features are ready."
                                : "You're typing with Neural Key."
                        )
                    }

                    if !isFullAccessOn {
                        fullAccessReminder
                    }
                }
            },
            footer: {
                OnboardingActions(
                    primaryTitle: isActive ? "Finish Setup" : "Continue",
                    primaryAction: {
                        isFieldFocused = false
                        viewModel.advance()
                    }
                )
            }
        )
    }

    private var testField: some View {
        VStack(alignment: .leading, spacing: NKSpacing.xs) {
            Text("TEST YOUR KEYBOARD")
                .nkFont(.overline)
                .tracking(1.2)
                .foregroundColor(NKColor.textSecondary)

            TextField(
                "",
                text: $sampleText,
                prompt: Text("Type something amazing…").foregroundColor(NKColor.textTertiary),
                axis: .vertical
            )
            .lineLimit(1...3)
            .nkFont(.body)
            .foregroundColor(NKColor.textPrimary)
            .focused($isFieldFocused)
            .padding(.horizontal, NKSpacing.m)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous)
                    .fill(NKColor.surfaceField)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous)
                    .stroke(isFieldFocused ? NKColor.brand : NKColor.border, lineWidth: isFieldFocused ? 1.5 : 1)
            )
            .shadow(color: NKColor.brand.opacity(isFieldFocused ? 0.3 : 0), radius: 14, x: 0, y: 0)
            .accessibilityLabel(Text("Test your keyboard"))
        }
    }

    /// Shown while Full Access is off or unconfirmed. Without it the keyboard cannot report
    /// in, so the copy stays neutral rather than claiming something is wrong.
    private var fullAccessReminder: some View {
        VStack(alignment: .leading, spacing: NKSpacing.xs) {
            NKStatusBanner(
                kind: .info,
                title: "AI features need Full Access",
                message: "Typing works either way. Turn on Full Access to use Improve, Translate and Tone."
            )
            Button {
                isFieldFocused = false
                viewModel.openSettings()
            } label: {
                Text("Turn on Full Access")
            }
            .buttonStyle(.nkTextAccent)
        }
    }
}
