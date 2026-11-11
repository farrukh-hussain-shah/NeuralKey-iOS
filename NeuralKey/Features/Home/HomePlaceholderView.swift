import SwiftUI

/// TEMPORARY — Phase 1 landing screen so the app is usable end to end after onboarding.
/// Phase 2 replaces this with the Home board (test field, typing & feedback, rewrites,
/// AI Hub) and the Settings screen. Nothing here is final design.
struct HomePlaceholderView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var keyboardMonitor: KeyboardSetupMonitor

    @State private var sampleText = ""
    @State private var isHelpPresented = false

    private var status: KeyboardSetupStatus { keyboardMonitor.status }

    var body: some View {
        ZStack {
            NKBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: NKSpacing.l) {
                    HStack(spacing: NKSpacing.s) {
                        NKLogoMark(size: 36, glow: false)
                        Text(verbatim: "Neural Key")
                            .nkFont(.headline)
                            .foregroundColor(NKColor.textPrimary)
                        Spacer()
                    }

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
                        .lineLimit(1...4)
                        .nkFont(.body)
                        .foregroundColor(NKColor.textPrimary)
                        .padding(NKSpacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous)
                                .fill(NKColor.surfaceField)
                        )
                        .accessibilityLabel(Text("Test your keyboard"))
                    }

                    VStack(alignment: .leading, spacing: NKSpacing.m) {
                        Text("SETUP")
                            .nkFont(.overline)
                            .tracking(1.2)
                            .foregroundColor(NKColor.textSecondary)

                        NKInfoRow(
                            systemImage: status.isKeyboardAdded ? "checkmark" : "exclamationmark",
                            title: status.isKeyboardAdded ? "Keyboard added" : "Keyboard not added",
                            message: status.isKeyboardAdded
                                ? "Touch and hold the globe key to switch to Neural Key."
                                : "Neural Key was removed from your keyboards. Run setup to add it again.",
                            tint: status.isKeyboardAdded ? NKColor.success : NKColor.warning
                        )
                        NKInfoRow(
                            systemImage: status.fullAccess == .granted ? "checkmark" : "exclamationmark",
                            title: status.fullAccess == .granted ? "AI features on" : "AI features off",
                            message: status.fullAccess == .granted
                                ? "Improve, Translate and Tone are ready."
                                : "Turn on Allow Full Access in Settings to use Improve, Translate and Tone.",
                            tint: status.fullAccess == .granted ? NKColor.success : NKColor.warning
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .nkCard()

                    VStack(spacing: NKSpacing.xxs) {
                        if !status.isAIReady {
                            Button {
                                appState.settings.openAppSettings()
                            } label: {
                                Label("Open Settings", systemImage: "arrow.up.forward.app")
                            }
                            .buttonStyle(.nkPrimary)
                        }
                        Button("Run setup again") { appState.restartOnboarding() }
                            .buttonStyle(.nkText)
                        Button("Setup help") { isHelpPresented = true }
                            .buttonStyle(.nkTextAccent)
                    }
                }
                .padding(NKSpacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $isHelpPresented) {
            TroubleshootingView(status: status, onOpenSettings: { appState.settings.openAppSettings() })
        }
    }
}
