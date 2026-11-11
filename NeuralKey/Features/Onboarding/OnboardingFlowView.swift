import SwiftUI

/// Container for the whole first-run experience. Owns the view model and swaps steps.
struct OnboardingFlowView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: @autoclosure @escaping () -> OnboardingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ZStack {
            NKBackground()

            Group {
                switch viewModel.step {
                case .intro:
                    IntroPagerView(viewModel: viewModel)
                case .addKeyboard:
                    AddKeyboardStepView(viewModel: viewModel)
                case .fullAccess:
                    FullAccessStepView(viewModel: viewModel)
                case .tryKeyboard:
                    TryKeyboardStepView(viewModel: viewModel)
                case .complete:
                    OnboardingCompleteView(viewModel: viewModel)
                }
            }
            .transition(.opacity)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: viewModel.step)
        .sheet(isPresented: $viewModel.isHelpPresented) {
            TroubleshootingView(
                status: viewModel.status,
                onOpenSettings: { viewModel.openSettings() }
            )
        }
    }
}
