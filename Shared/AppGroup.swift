import Foundation

/// Identifiers shared by the app and the keyboard extension.
///
/// Values are read from each target's Info.plist, which is fed by
/// `Config/Shared.xcconfig`, so there is exactly one place to change them.
enum AppGroup {
    /// App Group container identifier, e.g. `group.com.neuralkey.aikeyboard`.
    static let identifier: String = infoString("NKAppGroupIdentifier")

    /// Bundle identifier of the keyboard extension.
    static let keyboardBundleIdentifier: String = infoString("NKKeyboardBundleIdentifier")

    /// Shared defaults. `nil` when the App Group entitlement is missing or misconfigured,
    /// so callers must treat shared state as optional rather than crash.
    static let defaults: UserDefaults? = identifier.isEmpty ? nil : UserDefaults(suiteName: identifier)

    private static func infoString(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
    }
}
