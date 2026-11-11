import Foundation

/// Every screen in the first-run experience, in order.
enum OnboardingStep: String, CaseIterable, Equatable {
    case intro
    case addKeyboard
    case fullAccess
    case tryKeyboard
    case complete

    /// 1-based position among the three setup steps, or `nil` for intro and completion.
    var setupIndex: Int? {
        switch self {
        case .addKeyboard: return 1
        case .fullAccess: return 2
        case .tryKeyboard: return 3
        case .intro, .complete: return nil
        }
    }

    static let setupStepCount = 3
}

/// Navigation rules for onboarding. Pure functions, no UI or storage, so they can be
/// unit tested exhaustively.
enum OnboardingFlow {
    /// Where to resume when the app is relaunched part-way through onboarding.
    ///
    /// A user who left for Settings and had the app terminated in the background must land
    /// back on the step they were doing, not at the start. If the keyboard has since been
    /// removed, they are sent back to the step that fixes it.
    static func initialStep(saved: OnboardingStep?, status: KeyboardSetupStatus) -> OnboardingStep {
        guard let saved = saved else { return .intro }
        switch saved {
        case .intro:
            return .intro
        case .addKeyboard:
            return .addKeyboard
        case .fullAccess, .tryKeyboard, .complete:
            return status.isKeyboardAdded ? saved : .addKeyboard
        }
    }

    /// The flow is strictly linear. Steps that are already satisfied are still shown, in
    /// their "done" state, so the user always sees the same three-step journey.
    static func next(after step: OnboardingStep) -> OnboardingStep {
        switch step {
        case .intro: return .addKeyboard
        case .addKeyboard: return .fullAccess
        case .fullAccess: return .tryKeyboard
        case .tryKeyboard, .complete: return .complete
        }
    }

    static func previous(before step: OnboardingStep) -> OnboardingStep? {
        switch step {
        case .intro, .complete: return nil
        case .addKeyboard: return .intro
        case .fullAccess: return .addKeyboard
        case .tryKeyboard: return .fullAccess
        }
    }
}

/// Persists onboarding progress across launches.
final class OnboardingStore {
    private enum Key {
        static let completed = "nk.onboarding.completed"
        static let step = "nk.onboarding.step"
        static let fullAccessSkipped = "nk.onboarding.fullAccessSkipped"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isCompleted: Bool {
        get { defaults.bool(forKey: Key.completed) }
        set { defaults.set(newValue, forKey: Key.completed) }
    }

    var savedStep: OnboardingStep? {
        get { defaults.string(forKey: Key.step).flatMap(OnboardingStep.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: Key.step) }
    }

    var didSkipFullAccess: Bool {
        get { defaults.bool(forKey: Key.fullAccessSkipped) }
        set { defaults.set(newValue, forKey: Key.fullAccessSkipped) }
    }

    func reset() {
        defaults.removeObject(forKey: Key.completed)
        defaults.removeObject(forKey: Key.step)
        defaults.removeObject(forKey: Key.fullAccessSkipped)
    }
}
