import XCTest

/// End-to-end walkthrough for the demo video: the real first-run journey, including the
/// trip to the Settings app to add the keyboard, Allow Full Access, switching to
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

    /// Must match APP_BUNDLE_ID in Config/Shared.xcconfig. Settings lists the app under it.
    private let appBundleID = "com.neuralkey.aikeyboard"

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    // MARK: - The walkthrough

    func testFullSetupWalkthrough() {
        // Warm-up, before the recording starts. The first app launch in a test session takes
        // 30-40 s on CI and Settings is sluggish on its first run; doing both once here keeps
        // that dead time out of the video.
        app.launch()
        _ = waitForButton("Continue", timeout: 90)
        app.terminate()
        settings.launch()
        _ = settings.buttons["com.apple.settings.general"].waitForExistence(timeout: 30)
        settings.terminate()
        pause(1.0)

        marker("NK_VIDEO_START")
        pause(2.5)
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
        let keyboardAdded = enableKeyboardInSettings()
        note("keyboard switched on in Settings: \(keyboardAdded)")

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
        var fullAccessGranted = false
        if waitForButton("Not now", timeout: 8) {
            pause(2.0)
            tapButton("Open Settings")
            fullAccessGranted = allowFullAccessInSettings()
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
            var typedCount = typeWithOnScreenKeys("Hello")
            note("characters typed with on-screen keys: \(typedCount) of 5")
            if typedCount == 0 && switched {
                typedCount = typeHelloByPosition(showsFullAccessNotice: !fullAccessGranted)
                note("characters typed by key position: \(typedCount) of 5")
            }
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

    // "Open Settings" deep-links to the app's own page, Settings › Apps › Neural Key, which
    // has a Keyboards row holding both switches. On a slow machine the link takes several
    // seconds to get there (it passes through the main list and the Apps list), so the test
    // waits for it and only steps in if it stalls. Touching Settings while the link is still
    // travelling is what broke the earlier attempts.

    private var keyboardsRow: XCUIElement { settings.buttons["KEYBOARDS"] }
    private var keyboardSwitch: XCUIElement {
        settings.switches.matching(labelContains("Neural Key")).firstMatch
    }
    private var fullAccessSwitch: XCUIElement {
        settings.switches.matching(labelContains("Full Access")).firstMatch
    }

    /// Settings › Apps › Neural Key › Keyboards › Neural Key switch.
    private func enableKeyboardInSettings() -> Bool {
        guard settings.wait(for: .runningForeground, timeout: 20) else {
            note("FAILED Settings did not come to the foreground")
            return false
        }
        guard openKeyboardsPage(isFirstVisit: true) else { return false }

        guard keyboardSwitch.waitForExistence(timeout: 6) else {
            note("FAILED Neural Key switch not found on the Keyboards page")
            dump("settings (Keyboards page)", settings)
            return false
        }
        pause(1.0)
        turnOn(keyboardSwitch)
        pause(1.2)
        return isOn(keyboardSwitch)
    }

    /// Same page, Allow Full Access switch, then the system confirmation.
    private func allowFullAccessInSettings() -> Bool {
        guard settings.wait(for: .runningForeground, timeout: 20) else {
            note("FAILED Settings did not come to the foreground (second visit)")
            return false
        }
        guard openKeyboardsPage(isFirstVisit: false) else { return false }

        guard fullAccessSwitch.waitForExistence(timeout: 6) else {
            note("FAILED Allow Full Access switch not found on the Keyboards page")
            dump("settings (Keyboards page, second visit)", settings)
            return false
        }
        pause(1.0)
        turnOn(fullAccessSwitch)

        if let allow = allowButton(timeout: 5) {
            pause(1.2)
            allow.tap()
        } else {
            note("no confirmation alert appeared after Allow Full Access")
            dump("settings (after tapping Allow Full Access)", settings)
        }
        pause(1.2)
        return isOn(fullAccessSwitch)
    }

    /// Ends on the page with the keyboard switches. Waits for the deep link first.
    private func openKeyboardsPage(isFirstVisit: Bool) -> Bool {
        // 1. Let the deep link finish. No taps, no swipes. On a return visit Settings is
        //    already on a page, so give the link a moment to move before looking.
        if !isFirstVisit {
            pause(2.5)
        }
        let deadline = Date().addingTimeInterval(isFirstVisit ? 30 : 12)
        var arrived = false
        while Date() < deadline {
            if keyboardSwitch.exists || fullAccessSwitch.exists || keyboardsRow.exists {
                arrived = true
                break
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        note("Settings deep link reached the app page: \(arrived) (page: \(currentSettingsPage))")

        // 2. If it stalled, walk there: Apps › Neural Key.
        if !arrived {
            guard openAppPageManually() else { return false }
        }

        // 3. Already on the Keyboards page (second visit usually is)?
        if keyboardSwitch.exists || fullAccessSwitch.exists {
            return true
        }
        guard keyboardsRow.waitForExistence(timeout: 5) else {
            note("FAILED Keyboards row not found on the app's Settings page")
            dump("settings (app page)", settings)
            return false
        }
        pause(1.2)
        keyboardsRow.tap()
        pause(1.0)
        return true
    }

    private func openAppPageManually() -> Bool {
        let appRow = settings.buttons[appBundleID]
        if !appRow.exists {
            // Not on the Apps list yet: open it from the main list.
            let appsRow = settings.buttons["com.apple.settings.apps"]
            if scrollToFind(appsRow) {
                appsRow.tap()
                pause(1.0)
            }
        }
        guard scrollToFind(appRow) else {
            note("FAILED Neural Key not found under Settings › Apps")
            dump("settings (looking for the app row)", settings)
            return false
        }
        pause(0.6)
        appRow.tap()
        pause(1.0)
        return true
    }

    /// Looks for a row, scrolling the list back up first and then down.
    private func scrollToFind(_ element: XCUIElement) -> Bool {
        if element.exists && element.isHittable { return true }
        for _ in 0..<4 {
            settings.swipeDown()
            pause(0.4)
            if element.exists && element.isHittable { return true }
        }
        for _ in 0..<8 {
            settings.swipeUp()
            pause(0.4)
            if element.exists && element.isHittable { return true }
        }
        return false
    }

    private var currentSettingsPage: String {
        let bar = settings.navigationBars.firstMatch
        return bar.exists ? bar.identifier : "unknown"
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
        // Settings rows are wide; the switch itself sits at the trailing edge.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        pause(0.8)
        if allowButton(timeout: 0.5) != nil || isOn(toggle) {
            return
        }
        toggle.tap()
        pause(0.8)
    }

    // MARK: - Keyboard

    /// True when Neural Key is the keyboard on screen. Three signals, strongest first:
    /// the app's "Neural Key is active" banner (the keyboard reported in through the App
    /// Group), Neural Key's own space bar ("Space", capital S), or a keyboard being up with
    /// none of the system keyboards' key elements.
    private var isNeuralKeyActive: Bool {
        if app.descendants(matching: .any).matching(labelContains("Neural Key is active")).firstMatch.exists {
            return true
        }
        if app.buttons["Space"].exists {
            return true
        }
        return app.otherElements["inputView"].firstMatch.exists && app.keys.count == 0
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

    /// Last resort when Neural Key's keys are not exposed to the test: tap where the keys
    /// are, using the layout constants from KeyboardView (4 pt side padding, 6 pt key gap,
    /// 44 pt rows, 10 pt row gap, 8 pt top padding, optional 30 pt notice strip).
    private func typeHelloByPosition(showsFullAccessNotice: Bool) -> Int {
        let inputView = app.otherElements["inputView"].firstMatch
        guard inputView.exists else { return 0 }
        let frame = inputView.frame
        let rowWidth = frame.width - 8
        let top = frame.minY + 8 + (showsFullAccessNotice ? 30 : 0)

        func point(row: Int, index: Int) -> CGPoint {
            let keyCount: CGFloat = row == 0 ? 10 : 9
            let inset: CGFloat = row == 0 ? 0 : 0.5
            let unit = (rowWidth - 6 * (keyCount - 1)) / (keyCount + inset * 2)
            let x = frame.minX + 4 + inset * unit + CGFloat(index) * (unit + 6) + unit / 2
            let y = top + CGFloat(row) * 54 + 22
            return CGPoint(x: x, y: y)
        }

        // H e l l o  →  (row, index) on the QWERTY layout.
        let keys = [(1, 5), (0, 2), (1, 8), (1, 8), (0, 8)]
        let origin = app.coordinate(withNormalizedOffset: .zero)
        for (row, index) in keys {
            let target = point(row: row, index: index)
            origin.withOffset(CGVector(dx: target.x, dy: target.y)).tap()
            pause(0.3)
        }
        return keys.count
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
