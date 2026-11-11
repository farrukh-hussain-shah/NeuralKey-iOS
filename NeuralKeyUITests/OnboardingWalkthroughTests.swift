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
        let keyboardAdded = addKeyboardInSettings()
        note("keyboard added in Settings: \(keyboardAdded)")

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

        if usesExternalRecorder {
            probeAppSettingsPage()
        }
    }

    // MARK: - Settings

    // On the iOS 26 Simulator the app's "Open Settings" link lands on the main Settings
    // list, so the keyboard is added the long way:
    // General › Keyboard › Keyboards › Add New Keyboard… › Neural Key.

    /// Adds Neural Key to the keyboard list. Returns true once it is listed.
    private func addKeyboardInSettings() -> Bool {
        guard settings.wait(for: .runningForeground, timeout: 15) else {
            note("FAILED Settings did not come to the foreground")
            return false
        }
        pause(1.0)
        note("Settings opened on page: \(currentSettingsPage)")

        guard openKeyboardsList() else { return false }
        if settingsRow(beginsWith("Neural Key"), timeout: 1, scrolling: false) != nil {
            return true
        }

        guard let addRow = settingsRow(beginsWith("Add New Keyboard"), timeout: 4, scrolling: true) else {
            note("FAILED Add New Keyboard row not found")
            dump("settings (keyboards list)", settings)
            return false
        }
        pause(0.8)
        addRow.tap()
        pause(1.0)

        guard let neuralKey = settingsRow(beginsWith("Neural Key"), timeout: 5, scrolling: true) else {
            note("FAILED Neural Key is not offered in the Add New Keyboard list")
            dump("settings (add new keyboard)", settings)
            return false
        }
        pause(0.8)
        neuralKey.tap()
        pause(1.5)

        let listed = settingsRow(beginsWith("Neural Key"), timeout: 4, scrolling: false) != nil
        if !listed {
            note("FAILED Neural Key was tapped but is not in the keyboards list afterwards")
            dump("settings (after adding)", settings)
        }
        return listed
    }

    /// Keyboards › Neural Key › Allow Full Access, then the system confirmation.
    private func allowFullAccessInSettings() -> Bool {
        guard settings.wait(for: .runningForeground, timeout: 15) else {
            note("FAILED Settings did not come to the foreground (second visit)")
            return false
        }
        pause(1.0)
        note("Settings opened on page (second visit): \(currentSettingsPage)")

        guard openKeyboardsList() else { return false }
        guard let neuralKey = settingsRow(beginsWith("Neural Key"), timeout: 4, scrolling: false) else {
            note("FAILED Neural Key row not found in the keyboards list")
            dump("settings (keyboards list, second visit)", settings)
            return false
        }
        pause(0.8)
        neuralKey.tap()
        pause(1.0)

        let toggle = firstExisting([
            settings.switches["Allow Full Access"],
            settings.switches.matching(labelContains("Full Access")).firstMatch
        ], timeout: 5)
        guard let toggle = toggle else {
            note("FAILED Allow Full Access switch not found")
            dump("settings (keyboard detail page)", settings)
            return false
        }
        pause(0.8)
        turnOn(toggle)

        if let allow = allowButton(timeout: 5) {
            pause(1.2)
            allow.tap()
        } else {
            note("no confirmation alert appeared after Allow Full Access")
            dump("settings (after tapping Allow Full Access)", settings)
        }
        pause(1.2)
        return isOn(toggle)
    }

    /// Walks from wherever Settings is to General › Keyboard › Keyboards.
    private func openKeyboardsList() -> Bool {
        let addNew = beginsWith("Add New Keyboard")
        if settingsRow(addNew, timeout: 1.5, scrolling: false) != nil {
            return true
        }

        if let keyboards = settingsRow(beginsWith("Keyboards"), timeout: 1, scrolling: false) {
            keyboards.tap()
        } else {
            if settingsRow(exactly("Keyboard"), timeout: 1, scrolling: false) == nil {
                guard let general = settingsRow(exactly("General"), timeout: 4, scrolling: true) else {
                    note("FAILED General row not found in Settings")
                    dump("settings (looking for General)", settings)
                    return false
                }
                pause(0.8)
                general.tap()
                pause(1.0)
            }
            guard let keyboard = settingsRow(exactly("Keyboard"), timeout: 3, scrolling: true) else {
                note("FAILED Keyboard row not found under General")
                dump("settings (General page)", settings)
                return false
            }
            pause(0.6)
            keyboard.tap()
            pause(1.0)
            guard let keyboards = settingsRow(beginsWith("Keyboards"), timeout: 5, scrolling: false) else {
                note("FAILED Keyboards row not found on the Keyboard page")
                dump("settings (Keyboard page)", settings)
                return false
            }
            pause(0.6)
            keyboards.tap()
        }
        pause(1.0)

        if settingsRow(addNew, timeout: 5, scrolling: true) == nil {
            note("FAILED keyboards list did not open")
            dump("settings (expected the keyboards list)", settings)
            return false
        }
        return true
    }

    private var currentSettingsPage: String {
        let bar = settings.navigationBars.firstMatch
        return bar.exists ? bar.identifier : "unknown"
    }

    /// A tappable row in Settings whose label matches. Rows are buttons on iOS 26, cells or
    /// plain text on older layouts; navigation-bar titles are deliberately not searched.
    private func settingsRow(_ predicate: NSPredicate, timeout: TimeInterval, scrolling: Bool) -> XCUIElement? {
        let candidates = [
            settings.collectionViews.buttons.matching(predicate).firstMatch,
            settings.tables.buttons.matching(predicate).firstMatch,
            settings.cells.matching(predicate).firstMatch,
            settings.collectionViews.staticTexts.matching(predicate).firstMatch,
            settings.tables.staticTexts.matching(predicate).firstMatch
        ]
        if let found = firstExisting(candidates, timeout: timeout), found.isHittable {
            return found
        }
        guard scrolling else { return nil }
        for _ in 0..<6 {
            settings.swipeUp()
            pause(0.4)
            if let found = firstExisting(candidates, timeout: 0.4), found.isHittable {
                return found
            }
        }
        return nil
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

    /// Diagnostic only, run after the recording has stopped: looks at the app's own page in
    /// Settings (Settings › Apps › Neural Key) and logs what it contains, to settle whether
    /// that page offers a Keyboards row, which is what the onboarding copy currently says.
    private func probeAppSettingsPage() {
        settings.activate()
        _ = settings.wait(for: .runningForeground, timeout: 10)
        pause(1.0)
        // Back out to the main Settings list.
        for _ in 0..<6 {
            if settingsRow(exactly("General"), timeout: 0.5, scrolling: false) != nil { break }
            let back = settings.navigationBars.buttons.firstMatch
            guard back.exists else { break }
            back.tap()
            pause(0.8)
        }
        guard let apps = settingsRow(exactly("Apps"), timeout: 2, scrolling: true) else {
            note("PROBE Apps row not found in Settings")
            dump("settings probe (main list, scrolled)", settings)
            return
        }
        apps.tap()
        pause(1.0)
        guard let appRow = settingsRow(beginsWith("Neural Key"), timeout: 3, scrolling: true) else {
            note("PROBE Neural Key has no entry under Settings › Apps")
            dump("settings probe (Apps list)", settings)
            return
        }
        appRow.tap()
        pause(1.2)
        let hasKeyboardsRow = settingsRow(beginsWith("Keyboards"), timeout: 2, scrolling: false) != nil
        note("PROBE app page in Settings has a Keyboards row: \(hasKeyboardsRow)")
        dump("settings probe (Neural Key app page)", settings)
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

    private func beginsWith(_ text: String) -> NSPredicate {
        NSPredicate(format: "label BEGINSWITH[c] %@", text)
    }

    private func exactly(_ text: String) -> NSPredicate {
        NSPredicate(format: "label ==[c] %@", text)
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
