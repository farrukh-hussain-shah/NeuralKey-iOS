import Combine
import Foundation

/// Drives the onboarding flow: current step, reactions to setup status, and user actions.
@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: Published state

    @Published private(set) var step: OnboardingStep
    @Published private(set) var status: KeyboardSetupStatus
    @Published var introPage = 0
    @Published var isHelpPresented = false

    /// True once the user has been sent to Settings from the current step. Used to switch
    /// from "go do it" messaging to "didn't work?" messaging when they come back.
    @Published private(set) var hasOpenedSettings = false

    /// The moment the "try it" step was shown; keyboard activity after this counts as proof
    /// that the user managed to switch to Neural Key.
    @Published private(set) var tryStepEnteredAt = Date()

    let introPageCount: Int

    // MARK: Dependencies

    private let monitor: KeyboardSetupMonitor
    private let store: OnboardingStore
    private let settings: SettingsOpening
    private let analytics: AnalyticsTracking
    private let onFinish: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(
        monitor: KeyboardSetupMonitor,
        store: OnboardingStore,
        settings: SettingsOpening,
        analytics: AnalyticsTracking,
        introPageCount: Int = IntroPage.all.count,
        onFinish: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.store = store
        self.settings = settings
        self.analytics = analytics
        self.introPageCount = introPageCount
        self.onFinish = onFinish
        self.status = monitor.status
        self.step = OnboardingFlow.initialStep(saved: store.savedStep, status: monitor.status)

        monitor.$status
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newStatus in
                Task { @MainActor [weak self] in self?.handleStatusChange(newStatus) }
            }
            .store(in: &cancellables)

        analytics.track(.onboardingStepViewed(step: step.rawValue))
    }

    // MARK: Derived state

    var isLastIntroPage: Bool { introPage >= introPageCount - 1 }

    /// The keyboard reported being on screen after the try step opened.
    var isKeyboardActiveNow: Bool {
        guard let lastActive = status.lastActiveAt else { return false }
        return lastActive >= tryStepEnteredAt
    }

    /// The user came back from Settings but the keyboard still is not detected.
    var showsKeyboardNotDetected: Bool {
        step == .addKeyboard && hasOpenedSettings && !status.isKeyboardAdded
    }

    var canGoBack: Bool { OnboardingFlow.previous(before: step) != nil }

    // MARK: Intro

    func continueFromIntro() {
        if isLastIntroPage {
            go(to: .addKeyboard)
        } else {
            introPage += 1
        }
    }

    func skipIntro() {
        go(to: .addKeyboard)
    }

    // MARK: Setup actions

    func openSettings() {
        hasOpenedSettings = true
        analytics.track(.onboardingSettingsOpened(step: step.rawValue))
        settings.openAppSettings()
    }

    /// Moves to the next step. Also used for the manual "I've already added it" path when
    /// detection is unavailable, so the user is never trapped.
    func advance() {
        go(to: OnboardingFlow.next(after: step))
    }

    func goBack() {
        guard let previous = OnboardingFlow.previous(before: step) else { return }
        if previous == .intro {
            introPage = max(introPageCount - 1, 0)
        }
        go(to: previous)
    }

    /// Full Access is optional: the keyboard must stay useful without it (App Review 4.4.1).
    func skipFullAccess() {
        store.didSkipFullAccess = true
        analytics.track(.onboardingFullAccessSkipped)
        go(to: .tryKeyboard)
    }

    func showHelp() {
        analytics.track(.onboardingHelpOpened(step: step.rawValue))
        isHelpPresented = true
    }

    func finish() {
        store.isCompleted = true
        store.savedStep = nil
        analytics.track(.onboardingCompleted(fullAccessGranted: status.fullAccess == .granted))
        onFinish()
    }

    /// Manual refresh, e.g. pull-to-check from the help sheet.
    func refreshStatus() {
        monitor.refresh()
    }

    // MARK: Private

    private func go(to newStep: OnboardingStep) {
        guard newStep != step else { return }
        step = newStep
        hasOpenedSettings = false
        store.savedStep = newStep
        if newStep == .tryKeyboard {
            tryStepEnteredAt = Date()
        }
        analytics.track(.onboardingStepViewed(step: newStep.rawValue))
    }

    private func handleStatusChange(_ newStatus: KeyboardSetupStatus) {
        let previous = status
        status = newStatus

        if !previous.isKeyboardAdded && newStatus.isKeyboardAdded {
            analytics.track(.onboardingKeyboardAdded)
            Haptics.success()
        }
        if previous.fullAccess != .granted && newStatus.fullAccess == .granted {
            store.didSkipFullAccess = false
            analytics.track(.onboardingFullAccessGranted)
            Haptics.success()
        }
        // The keyboard was removed while the user was on a later step: send them back.
        let wasRemoved = previous.isKeyboardAdded && !newStatus.isKeyboardAdded
        let isPastAddStep = step == .fullAccess || step == .tryKeyboard || step == .complete
        if wasRemoved && isPastAddStep {
            go(to: .addKeyboard)
        }
    }
}
