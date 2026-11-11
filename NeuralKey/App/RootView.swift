import SwiftUI

/// Switches between launch, onboarding and the main app.
struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch appState.phase {
            case .launching:
                SplashView(onFinished: { appState.finishLaunching() })
                    .transition(.opacity)
            case .onboarding:
                OnboardingFlowView(viewModel: appState.makeOnboardingViewModel())
                    .transition(.opacity)
            case .main:
                HomePlaceholderView()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: appState.phase)
    }
}
