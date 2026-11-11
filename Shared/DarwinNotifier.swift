import Foundation

/// Cross-process signals between the keyboard extension and the app.
///
/// Darwin notifications carry no payload; they only say "something changed, re-read the
/// shared state". Delivery is best effort, so nothing may depend on them for correctness —
/// the app also refreshes whenever it becomes active.
enum DarwinNotificationName: String {
    case keyboardStateChanged = "com.neuralkey.keyboard.stateChanged"
}

enum DarwinNotifier {
    static func post(_ name: DarwinNotificationName) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: name.rawValue as CFString),
            nil,
            nil,
            true
        )
    }
}

/// Observes a Darwin notification for as long as the instance is alive.
/// The handler is always invoked on the main queue.
final class DarwinNotificationObserver {
    private let name: CFString
    private let handler: () -> Void

    init(_ name: DarwinNotificationName, handler: @escaping () -> Void) {
        self.name = name.rawValue as CFString
        self.handler = handler

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let instance = Unmanaged<DarwinNotificationObserver>
                    .fromOpaque(observer)
                    .takeUnretainedValue()
                DispatchQueue.main.async { instance.handler() }
            },
            self.name,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(rawValue: name),
            nil
        )
    }
}
