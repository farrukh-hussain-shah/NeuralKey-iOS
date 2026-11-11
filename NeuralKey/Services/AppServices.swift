import Foundation
import UIKit

// MARK: - Links

/// External destinations used across the app.
enum AppLinks {
    static let privacyPolicy = URL(string: "https://sites.google.com/view/neuralkey-ai-privacy-policy/home")!

    /// TODO(team): replace with Neural Key's own Terms of Use once published.
    /// Apple's standard EULA is used as the default because it is what applies to an
    /// App Store app that does not supply a custom one.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static let supportEmail = "neuralkeyboard1@gmail.com"

    static var supportMailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "Neural Key iOS — setup help")]
        return components.url
    }
}

// MARK: - Settings

protocol SettingsOpening {
    /// Opens this app's page in the Settings app.
    func openAppSettings()
}

/// Opens Settings › Neural Key, the page that contains the "Keyboards" row where the user
/// enables the keyboard and Full Access.
///
/// This is the only Settings deep link Apple supports. `App-prefs:` / `prefs:` URLs that
/// jump straight to General › Keyboard are private API and cause App Review rejection,
/// so they are deliberately not used.
struct SystemSettingsOpener: SettingsOpening {
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Haptics

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Analytics

/// Funnel events for onboarding. Names use snake_case to match Firebase conventions.
/// TODO(team): align names with the Android app's existing Analytics events before launch
/// so both platforms report into the same funnels.
enum AnalyticsEvent: Equatable {
    case onboardingStepViewed(step: String)
    case onboardingSettingsOpened(step: String)
    case onboardingKeyboardAdded
    case onboardingFullAccessGranted
    case onboardingFullAccessSkipped
    case onboardingHelpOpened(step: String)
    case onboardingCompleted(fullAccessGranted: Bool)

    var name: String {
        switch self {
        case .onboardingStepViewed: return "onboarding_step_viewed"
        case .onboardingSettingsOpened: return "onboarding_settings_opened"
        case .onboardingKeyboardAdded: return "onboarding_keyboard_added"
        case .onboardingFullAccessGranted: return "onboarding_full_access_granted"
        case .onboardingFullAccessSkipped: return "onboarding_full_access_skipped"
        case .onboardingHelpOpened: return "onboarding_help_opened"
        case .onboardingCompleted: return "onboarding_completed"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .onboardingStepViewed(let step),
             .onboardingSettingsOpened(let step),
             .onboardingHelpOpened(let step):
            return ["step": step]
        case .onboardingCompleted(let fullAccessGranted):
            return ["full_access": fullAccessGranted ? "granted" : "not_granted"]
        case .onboardingKeyboardAdded, .onboardingFullAccessGranted, .onboardingFullAccessSkipped:
            return [:]
        }
    }
}

protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

/// Placeholder sink used until Firebase Analytics is wired in Phase 2.
/// Events never contain user-typed text.
struct DebugAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {
        #if DEBUG
        print("[analytics] \(event.name) \(event.parameters)")
        #endif
    }
}
