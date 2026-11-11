import Foundation
import SwiftUI

/// App-level routing and long-lived services.
@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable {
        case launching
        case onboarding
        case main
    }

    @Published private(set) var phase: Phase = .launching

    let keyboardMonitor: KeyboardSetupMonitor
    let onboardingStore: OnboardingStore
    let settings: SettingsOpening
    let analytics: AnalyticsTracking

    init(
        keyboardMonitor: KeyboardSetupMonitor? = nil,
        onboardingStore: OnboardingStore = OnboardingStore(),
        settings: SettingsOpening = SystemSettingsOpener(),
        analytics: AnalyticsTracking = DebugAnalytics()
    ) {
        self.keyboardMonitor = keyboardMonitor ?? KeyboardSetupMonitor()
        self.onboardingStore = onboardingStore
        self.settings = settings
        self.analytics = analytics
    }

    /// Called by the splash screen when start-up work is done.
    func finishLaunching() {
        guard phase == .launching else { return }
        keyboardMonitor.refresh()
        phase = onboardingStore.isCompleted ? .main : .onboarding
    }

    func completeOnboarding() {
        phase = .main
    }

    /// Lets the user run setup again from the main app (e.g. after removing the keyboard).
    func restartOnboarding() {
        onboardingStore.reset()
        phase = .onboarding
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            monitor: keyboardMonitor,
            store: onboardingStore,
            settings: settings,
            analytics: analytics,
            onFinish: { [weak self] in self?.completeOnboarding() }
        )
    }
}
