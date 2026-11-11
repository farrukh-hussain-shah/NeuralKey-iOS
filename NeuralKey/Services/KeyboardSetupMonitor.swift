import Combine
import Foundation
import UIKit

// MARK: - Status model

enum FullAccessState: Equatable {
    /// The keyboard has never reported in, so we cannot tell. iOS gives the containing app
    /// no API for this; only the extension knows.
    case unknown
    case granted
    case denied
}

struct KeyboardSetupStatus: Equatable {
    var isKeyboardAdded: Bool
    var fullAccess: FullAccessState
    /// Last time the keyboard reported being on screen (requires Full Access).
    var lastActiveAt: Date?

    var isAIReady: Bool { isKeyboardAdded && fullAccess == .granted }

    static let notStarted = KeyboardSetupStatus(isKeyboardAdded: false, fullAccess: .unknown, lastActiveAt: nil)
}

// MARK: - Detection

protocol InstalledKeyboardsProviding {
    /// Identifiers of every keyboard enabled in Settings, or `nil` if the list is unavailable.
    func installedKeyboardIdentifiers() -> [String]?
}

/// Reads the list of enabled keyboards.
///
/// iOS has no public API that answers "is my keyboard enabled?". The `AppleKeyboards`
/// global default is the long-standing technique used by shipping keyboard apps. It is
/// undocumented, so the result is treated as a hint: when it is unavailable the onboarding
/// falls back to the user confirming manually, and nothing ever blocks on it.
struct SystemInstalledKeyboards: InstalledKeyboardsProviding {
    func installedKeyboardIdentifiers() -> [String]? {
        UserDefaults.standard.object(forKey: "AppleKeyboards") as? [String]
    }
}

/// Pure function from raw signals to a status. Kept separate so it is trivially testable.
struct KeyboardSetupStatusResolver {
    let keyboardBundleIdentifier: String

    func resolve(installedKeyboards: [String]?, report: KeyboardReport) -> KeyboardSetupStatus {
        let isListed: Bool
        if let installedKeyboards = installedKeyboards, !keyboardBundleIdentifier.isEmpty {
            isListed = installedKeyboards.contains { $0.contains(keyboardBundleIdentifier) }
        } else {
            // List unavailable: fall back to "the keyboard has run at least once".
            isListed = report.lastActiveAt != nil
        }

        guard isListed else { return .notStarted }

        let fullAccess: FullAccessState
        switch report.hasFullAccess {
        case .some(true): fullAccess = .granted
        case .some(false): fullAccess = .denied
        case .none: fullAccess = .unknown
        }

        return KeyboardSetupStatus(isKeyboardAdded: true, fullAccess: fullAccess, lastActiveAt: report.lastActiveAt)
    }
}

// MARK: - Monitor

/// Publishes the current keyboard setup status and keeps it fresh.
///
/// Refresh triggers: app becomes active (the user is returning from Settings) and a
/// Darwin notification from the keyboard extension (the user just opened the keyboard).
@MainActor
final class KeyboardSetupMonitor: ObservableObject {
    @Published private(set) var status: KeyboardSetupStatus = .notStarted

    private let installedKeyboards: InstalledKeyboardsProviding
    private let sharedState: KeyboardSharedState
    private let resolver: KeyboardSetupStatusResolver
    private var darwinObserver: DarwinNotificationObserver?
    private var cancellables = Set<AnyCancellable>()

    init(
        installedKeyboards: InstalledKeyboardsProviding = SystemInstalledKeyboards(),
        sharedState: KeyboardSharedState = KeyboardSharedState(),
        keyboardBundleIdentifier: String = AppGroup.keyboardBundleIdentifier,
        observesSystemEvents: Bool = true
    ) {
        self.installedKeyboards = installedKeyboards
        self.sharedState = sharedState
        self.resolver = KeyboardSetupStatusResolver(keyboardBundleIdentifier: keyboardBundleIdentifier)

        refresh()

        guard observesSystemEvents else { return }

        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            .store(in: &cancellables)

        darwinObserver = DarwinNotificationObserver(.keyboardStateChanged) { [weak self] in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    /// Re-reads every signal and publishes the result if it changed.
    func refresh() {
        let installed = installedKeyboards.installedKeyboardIdentifiers()
        var report = sharedState.report()

        // If the keyboard was removed in Settings, its old report is meaningless.
        let keyboardID = resolver.keyboardBundleIdentifier
        if let installed = installed,
           !keyboardID.isEmpty,
           !installed.contains(where: { $0.contains(keyboardID) }),
           report != .empty {
            sharedState.reset()
            report = .empty
        }

        let resolved = resolver.resolve(installedKeyboards: installed, report: report)
        if resolved != status {
            status = resolved
        }
    }
}
