import Foundation

/// Minimal key-value abstraction so shared state can be unit tested without an App Group.
protocol KeyValueStore: AnyObject {
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: KeyValueStore {}

/// What the keyboard extension last told the app about itself.
struct KeyboardReport: Equatable {
    /// Last time the keyboard was shown on screen (only recorded while Full Access is on,
    /// because iOS blocks writes to the shared container otherwise).
    var lastActiveAt: Date?
    /// Full Access state as seen by the extension. `nil` means "never reported".
    var hasFullAccess: Bool?
    var fullAccessReportedAt: Date?

    static let empty = KeyboardReport()
}

/// The small piece of state the keyboard extension shares with the app through the App Group.
///
/// Platform note: without Full Access the extension is sandboxed and its writes to the
/// shared container fail silently. That means a `true` value is trustworthy at the time it
/// was written, while a later revocation cannot be reported here. The keyboard itself always
/// checks `hasFullAccess` live before any AI action.
struct KeyboardSharedState {
    enum Key {
        static let lastActiveAt = "nk.keyboard.lastActiveAt"
        static let hasFullAccess = "nk.keyboard.hasFullAccess"
        static let fullAccessReportedAt = "nk.keyboard.fullAccessReportedAt"
    }

    private let store: KeyValueStore?

    init(store: KeyValueStore? = AppGroup.defaults) {
        self.store = store
    }

    /// Called by the keyboard extension every time it appears.
    func recordKeyboardAppeared(hasFullAccess: Bool, at date: Date = Date()) {
        guard let store = store else { return }
        let timestamp = date.timeIntervalSince1970
        store.set(timestamp, forKey: Key.lastActiveAt)
        store.set(hasFullAccess, forKey: Key.hasFullAccess)
        store.set(timestamp, forKey: Key.fullAccessReportedAt)
    }

    /// Called by the app to read the latest report.
    func report() -> KeyboardReport {
        guard let store = store else { return .empty }
        return KeyboardReport(
            lastActiveAt: date(from: store.object(forKey: Key.lastActiveAt)),
            hasFullAccess: store.object(forKey: Key.hasFullAccess) as? Bool,
            fullAccessReportedAt: date(from: store.object(forKey: Key.fullAccessReportedAt))
        )
    }

    /// Clears the report, e.g. when the keyboard has been removed from Settings.
    func reset() {
        guard let store = store else { return }
        store.set(nil, forKey: Key.lastActiveAt)
        store.set(nil, forKey: Key.hasFullAccess)
        store.set(nil, forKey: Key.fullAccessReportedAt)
    }

    private func date(from value: Any?) -> Date? {
        guard let interval = value as? Double else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
}
