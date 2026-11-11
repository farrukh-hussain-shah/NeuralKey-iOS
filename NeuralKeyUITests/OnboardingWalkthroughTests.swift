import XCTest

/// Taps through the whole onboarding in one continuous run, pausing on each screen.
/// The CI workflow records the Simulator while this test runs, producing a video of the
/// flow from splash to the home screen.
///
/// The keyboard is presented as "added" through a launch argument (see
/// OnboardingScreenshotTests for how that works), so the flow can move past step 1 without
/// leaving the app for Settings. Full Access is skipped with "Not now", because granting it
/// needs a real device.
final class OnboardingWalkthroughTests: XCTestCase {
    /// Must match KEYBOARD_BUNDLE_ID in Config/Shared.xcconfig.
    private let keyboardBundleID = "com.neuralkey.aikeyboard.keyboard"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func button(_ title: String, in app: XCUIApplication, timeout: TimeInterval = 20) -> XCUIElement {
        let element = app.buttons[title]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Expected a \"\(title)\" button")
        return element
    }

    /// Holds a screen long enough to be read in the recording.
    private func pause(_ seconds: TimeInterval = 2.0) {
        Thread.sleep(forTimeInterval: seconds)
    }

    func testWalkthrough() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-nk.onboarding.completed", "NO",
            "-nk.onboarding.step", "intro",
            "-AppleKeyboards", "(\"\(keyboardBundleID)\")"
        ]
        app.launch()

        // Splash, then the three intro pages.
        let continueButton = button("Continue", in: app)
        pause(2.5)
        continueButton.tap()
        pause()
        app.buttons["Continue"].tap()
        let setUpButton = button("Set Up Keyboard", in: app, timeout: 5)
        pause()
        setUpButton.tap()

        // Step 1: add keyboard (shown in its detected state).
        let helpButton = button("Help", in: app, timeout: 5)
        pause(2.5)

        // Setup Help: open, expand one answer, close.
        helpButton.tap()
        let doneButton = button("Done", in: app, timeout: 5)
        pause()
        let question = app.buttons["Is Full Access safe?"]
        if question.waitForExistence(timeout: 3) {
            question.tap()
            pause(3)
        }
        doneButton.tap()
        pause(1.5)

        // Step 2: Full Access, skipped.
        button("Continue", in: app, timeout: 5).tap()
        let notNowButton = button("Not now", in: app, timeout: 5)
        pause(3.5)
        notNowButton.tap()

        // Step 3: switch and try.
        let finishButton = button("Continue", in: app, timeout: 5)
        pause(3)
        finishButton.tap()

        // All set, then into the app.
        let startButton = button("Start Using Neural Key", in: app, timeout: 5)
        pause(3.5)
        startButton.tap()

        _ = button("Run setup again", in: app, timeout: 5)
        pause(2.5)
    }
}
