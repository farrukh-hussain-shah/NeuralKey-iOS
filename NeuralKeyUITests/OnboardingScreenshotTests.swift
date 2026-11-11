import XCTest

/// Walks the onboarding flow in the Simulator and saves a screenshot of every screen.
/// The CI workflow exports these so the UI can be reviewed without a Mac.
///
/// How states are reached without touching the Settings app:
/// launch arguments of the form `-key value` are read by `UserDefaults.standard` ahead of
/// stored values. That lets a test start on a given step and present the keyboard as
/// "added", using the app's normal code paths and no test-only code in the app.
///
/// Not covered here: the "Full Access is on" states. Those come from the keyboard extension
/// through the App Group and need a real device.
final class OnboardingScreenshotTests: XCTestCase {
    /// Must match KEYBOARD_BUNDLE_ID in Config/Shared.xcconfig.
    private let keyboardBundleID = "com.neuralkey.aikeyboard.keyboard"

    override func setUp() {
        super.setUp()
        // Keep going after a failed check so the remaining screenshots are still captured.
        continueAfterFailure = true
    }

    // MARK: - Helpers

    private func launchApp(step: String, keyboardAdded: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-nk.onboarding.completed", "NO",
            "-nk.onboarding.step", step
        ]
        if keyboardAdded {
            arguments += ["-AppleKeyboards", "(\"\(keyboardBundleID)\")"]
        } else {
            arguments += ["-AppleKeyboards", "(\"en_US@sw=QWERTY;hw=Automatic\")"]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForButton(_ title: String, in app: XCUIApplication, timeout: TimeInterval = 20) -> XCUIElement {
        let button = app.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Expected a \"\(title)\" button")
        return button
    }

    /// Lets transitions finish so screenshots are not taken mid-animation.
    private func settle() {
        Thread.sleep(forTimeInterval: 0.8)
    }

    // MARK: - Tests

    func test01_SplashAndIntro() {
        let app = launchApp(step: "intro", keyboardAdded: false)
        capture("00-splash")

        let continueButton = waitForButton("Continue", in: app)
        settle()
        capture("01-intro-improve")

        continueButton.tap()
        settle()
        capture("02-intro-translate")

        app.buttons["Continue"].tap()
        let setUpButton = waitForButton("Set Up Keyboard", in: app, timeout: 5)
        settle()
        capture("03-intro-tone")

        setUpButton.tap()
        _ = waitForButton("Open Settings", in: app, timeout: 5)
        settle()
        capture("04-add-keyboard")
    }

    func test02_SetupHelp() {
        let app = launchApp(step: "addKeyboard", keyboardAdded: false)
        waitForButton("Help", in: app).tap()
        _ = waitForButton("Done", in: app, timeout: 5)
        settle()
        capture("09-setup-help")
    }

    func test03_KeyboardAdded() {
        let app = launchApp(step: "addKeyboard", keyboardAdded: true)
        _ = waitForButton("Continue", in: app)
        settle()
        capture("05-add-keyboard-detected")
    }

    func test04_FullAccess() {
        let app = launchApp(step: "fullAccess", keyboardAdded: true)
        _ = waitForButton("Not now", in: app)
        settle()
        capture("06-full-access")
    }

    func test05_TryKeyboard() {
        let app = launchApp(step: "tryKeyboard", keyboardAdded: true)
        _ = waitForButton("Continue", in: app)
        settle()
        capture("07-try-keyboard")
    }

    func test06_Complete() {
        let app = launchApp(step: "complete", keyboardAdded: true)
        _ = waitForButton("Start Using Neural Key", in: app)
        settle()
        capture("08-all-set")
    }
}
