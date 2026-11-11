import XCTest

/// End-to-end walkthrough for the demo video: the real first-run journey, including the
/// trip to the Settings app to switch the keyboard on, Allow Full Access, switching to
/// Neural Key with the globe key, and typing with it.
///
/// Unlike OnboardingScreenshotTests, nothing is simulated here: the keyboard is really
/// enabled in Settings and the app has to detect it by itself.
///
/// Every stage is best effort. If a system screen does not look the way this test expects,
/// the test writes what it saw to the log (lines starting NK_NOTE / NK_DUMP), takes the
/// in-app fallback ("I've already added it", "Not now") and carries on, so a video is
/// always produced and the log says exactly which stage needs adjusting.
final class OnboardingWalkthroughTests: XCTestCase {
    private let app = XCUIApplication()
    private let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// Set by the CI workflow when an outside recorder needs a moment to start.
    private var usesExternalRecorder: Bool {
        ProcessInfo.processInfo.environment["NK_EXTERNAL_RECORDER"] == "1"
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    // MARK: - The walkthrough

    func testFullSetupWalkthrough() {
        marker("NK_VIDEO_START")
        if usesExternalRecorder {
            pause(2.5)
        }
        app.launch()

        // Intro pages.
        guard waitForButton("Continue", timeout: 40) else {
            note("FAILED intro did not appear")
            dump("app", app)
            return
        }
        pause(1.5)
        tapButton("Continue")
        pause(1.2)
        tapButton("Continue")
        _ = waitForButton("Set Up Keyboard", timeout: 6)
        pause(1.2)
        tapButton("Set Up Keyboard")

        // Step 1: add the keyboard in Settings.
        _ = waitForButton("Open Settings", timeout: 8)
        pause(1.5)
        tapButton("Open Settings")
        let keyboardEnabled = enableKeyboardInSettings()
        note("keyboard switched on in Settings: \(keyboardEnabled)")

        app.activate()
        pause(1.0)
        if waitForButton("Continue", timeout: 6) {
            note("app detected the keyboard: true")
            pause(1.2)
            tapButton("Continue")
        } else if app.buttons["I've already added it"].exists {
            note("app detected the keyboard: false (used manual button)")
            tapButton("I've already added it")
        } else {
            note("FAILED no way forward on the add-keyboard step")
            dump("app", app)
        }

        // Step 2: Allow Full Access.
        if waitForButton("Not now", timeout: 8) {
            pause(2.0)
            tapButton("Open Settings")
            let fullAccessGranted = allowFullAccessInSettings()
            note("Full Access switched on in Settings: \(fullAccessGranted)")

            app.activate()
            pause(1.0)
            if waitForButton("Continue", timeout: 6) {
                pause(1.0)
                tapButton("Continue")
            } else {
                tapButton("Not now")
            }
        } else {
            note("Full Access step was not shown in its initial state")
        }

        // Step 3: switch to Neural Key and type.
        let field = firstExisting([
            app.textViews["Test your keyboard"],
            app.textFields["Test your keyboard"],
            app.textViews.firstMatch,
            app.textFields.firstMatch
        ], timeout: 8)
        if let field = field {
            pause(1.5)
            field.tap()
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 6)
            pause(1.0)

            // First-use keyboard tips can cover the keys.
            let tip = app.keyboards.buttons["Continue"]
            if tip.exists {
                tip.tap()
                pause(0.8)
            }

            let switched = switchToNeuralKey()
            note("switched to Neural Key keyboard: \(switched)")
            let typedCount = typeWithOnScreenKeys("Hello")
            note("characters typed with on-screen keys: \(typedCount) of 5")
            pause(1.5)
        } else {
            note("FAILED test field not found")
            dump("app", app)
        }

        if let finish = firstExisting([app.buttons["Finish Setup"], app.buttons["Continue"]], timeout: 5) {
            finish.tap()
        }

        // All set, then into the app.
        if waitForButton("Start Using Neural Key", timeout: 8) {
            pause(2.0)
            tapButton("Start Using Neural Key")
            _ = waitForButton("Run setup again", timeout: 6)
            pause(1.5)
        } else {
            note("FAILED completion screen did not appear")
            dump("app", app)
        }

        marker("NK_VIDEO_END")
    }

    // MARK: - Settings

    /// Settings › Neural Key › Keyboards › Neural Key switch.
    private func enableKeyboardInSettings() -> Bool {
        guard settings.wait(for: .runningForeground, timeout: 15) else {
            note("FAILED Settings did not come to the foreground")
            return false
        }
        pause(1.0)
        openKeyboardsPageIfNeeded()

        let toggle = firstExisting([
            settings.switches["Neural Key"],
            settings.switches.matching(labelContains("Neural Key")).firstMatch
        ], timeout: 6)
        guard let toggle = toggle else {
            note("FAILED keyboard switch not found in Settings")
            dump("settings (looking for the Neural Key switch)", settings)
            return false
        }
        pause(0.8)
        turnOn(toggle)
        pause(1.2)
        return isOn(toggle)
    }

    /// Settings › Neural Key › Keyboards › Allow Full Access, then the system confirmation.
    private func allowFullAccessInSettings() -> Bool {
        guard settings.wait(for: .runningForeground, timeout: 15) else {
            note("FAILED Settings did not come to the foreground (second visit)")
            return false
        }
        pause(1.0)
        openKeyboardsPageIfNeeded()

        let toggle = firstExisting([
            settings.switches["Allow Full Access"],
            settings.switches.matching(labelContains("Full Access")).firstMatch
        ], timeout: 6)
        guard let toggle = toggle else {
            note("FAILED Allow Full Access switch not found in Settings")
            dump("settings (looking for Allow Full Access)", settings)
            return false
        }
        pause(0.8)
        turnOn(toggle)

        if let allow = allowButton(timeout: 5) {
            pause(1.2)
            allow.tap()
        } else {
            note("no confirmation alert appeared after Allow Full Access")
        }
        pause(1.2)
        return isOn(toggle)
    }

    private func openKeyboardsPageIfNeeded() {
        let anyKeyboardSwitch = settings.switches.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Neural Key", "Full Access")
        ).firstMatch
        if anyKeyboardSwitch.waitForExistence(timeout: 2) {
            return
        }
        let row = firstExisting([
            settings.cells.staticTexts["Keyboards"],
            settings.buttons["Keyboards"],
            settings.cells["Keyboards"],
            settings.staticTexts["Keyboards"],
            settings.links["Keyboards"]
        ], timeout: 6)
        guard let row = row else {
            note("FAILED Keyboards row not found on the app's Settings page")
            dump("settings (looking for the Keyboards row)", settings)
            return
        }
        pause(0.8)
        row.tap()
        pause(1.0)
    }

    private func allowButton(timeout: TimeInterval) -> XCUIElement? {
        firstExisting([
            settings.alerts.buttons["Allow"],
            springboard.alerts.buttons["Allow"],
            settings.buttons["Allow"],
            springboard.buttons["Allow"]
        ], timeout: timeout)
    }

    private func isOn(_ toggle: XCUIElement) -> Bool {
        (toggle.value as? String) == "1"
    }

    private func turnOn(_ toggle: XCUIElement) {
        guard !isOn(toggle) else { return }
        toggle.tap()
        pause(0.8)
        // A confirmation alert means the tap registered.
        if allowButton(timeout: 0.5) != nil || isOn(toggle) {
            return
        }
        // Some Settings rows only toggle when the switch itself is tapped.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        pause(0.8)
    }

    // MARK: - Keyboard

    private var isNeuralKeyActive: Bool {
        // "Neural Key is active" appears when the keyboard reports in through the App Group;
        // "Space" (capital S) is the accessibility label of Neural Key's own space bar.
        app.descendants(matching: .any).matching(labelContains("Neural Key is active")).firstMatch.exists
            || app.buttons["Space"].exists
    }

    private func globeKey(timeout: TimeInterval) -> XCUIElement? {
        firstExisting([
            app.buttons["Next keyboard"],
            app.keyboards.buttons["Next keyboard"],
            springboard.buttons["Next keyboard"]
        ], timeout: timeout)
    }

    private func switchToNeuralKey() -> Bool {
        if isNeuralKeyActive { return true }
        guard let globe = globeKey(timeout: 4) else {
            note("FAILED globe key not found")
            dump("app with the system keyboard up", app)
            return false
        }

        // As the onboarding instructs: touch and hold the globe, then pick Neural Key.
        globe.press(forDuration: 1.0)
        pause(0.6)
        let listItem = firstExisting([
            app.tables.staticTexts.matching(labelContains("Neural Key")).firstMatch,
            app.collectionViews.staticTexts.matching(labelContains("Neural Key")).firstMatch,
            app.tables.cells.matching(labelContains("Neural Key")).firstMatch,
            app.collectionViews.cells.matching(labelContains("Neural Key")).firstMatch
        ], timeout: 2)
        if let listItem = listItem {
            pause(0.8)
            listItem.tap()
            pause(1.5)
        } else {
            note("keyboard list item not found; tapping the globe to cycle instead")
        }

        var attempts = 0
        while !isNeuralKeyActive && attempts < 4 {
            guard let key = globeKey(timeout: 2) else { break }
            key.tap()
            pause(1.5)
            attempts += 1
        }

        if !isNeuralKeyActive {
            note("could not confirm Neural Key is the active keyboard")
            dump("app after trying to switch keyboards", app)
        }
        return isNeuralKeyActive
    }

    /// Types by tapping keys on whichever keyboard is showing. Returns how many keys it found.
    private func typeWithOnScreenKeys(_ text: String) -> Int {
        var typed = 0
        for character in text {
            let exact = String(character)
            let lower = exact.lowercased()
            let upper = exact.uppercased()
            let key = firstExisting([
                app.buttons[exact], app.keys[exact],
                app.buttons[upper], app.keys[upper],
                app.buttons[lower], app.keys[lower]
            ], timeout: 1)
            if let key = key {
                key.tap()
                typed += 1
                pause(0.25)
            }
        }
        return typed
    }

    // MARK: - Helpers

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func labelContains(_ text: String) -> NSPredicate {
        NSPredicate(format: "label CONTAINS[c] %@", text)
    }

    private func waitForButton(_ title: String, timeout: TimeInterval) -> Bool {
        app.buttons[title].waitForExistence(timeout: timeout)
    }

    private func tapButton(_ title: String) {
        let button = app.buttons[title]
        if button.exists {
            button.tap()
        } else {
            note("button not found: \(title)")
        }
    }

    private func firstExisting(_ candidates: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for candidate in candidates where candidate.exists {
                return candidate
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return nil
    }

    /// One-line finding in the test log.
    private func note(_ message: String) {
        XCTContext.runActivity(named: "NK_NOTE " + message) { _ in }
        print("NK_NOTE " + message)
        fflush(stdout)
    }

    /// Start/stop signal for an outside screen recorder: a log line plus a file it can poll.
    private func marker(_ name: String) {
        XCTContext.runActivity(named: name) { _ in }
        print(name)
        fflush(stdout)
        FileManager.default.createFile(atPath: "/tmp/" + name.lowercased(), contents: Data())
    }

    /// Writes the accessibility tree to the log so a failed stage can be fixed from the log alone.
    private func dump(_ title: String, _ application: XCUIApplication) {
        print("NK_DUMP_BEGIN " + title)
        print(application.debugDescription)
        print("NK_DUMP_END " + title)
        fflush(stdout)
    }
}
