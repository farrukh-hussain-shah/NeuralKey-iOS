import XCTest
@testable import NeuralKey

// MARK: - Test doubles

private final class InMemoryStore: KeyValueStore {
    private var values: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }
}

private struct StubInstalledKeyboards: InstalledKeyboardsProviding {
    var identifiers: [String]?

    func installedKeyboardIdentifiers() -> [String]? {
        identifiers
    }
}

private final class SpySettingsOpener: SettingsOpening {
    private(set) var openCount = 0

    func openAppSettings() {
        openCount += 1
    }
}

private final class SpyAnalytics: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}

private let keyboardID = "com.neuralkey.aikeyboard.keyboard"

// MARK: - Flow rules

final class OnboardingFlowTests: XCTestCase {
    private let added = KeyboardSetupStatus(isKeyboardAdded: true, fullAccess: .unknown, lastActiveAt: nil)

    func testFirstLaunchStartsAtIntro() {
        XCTAssertEqual(OnboardingFlow.initialStep(saved: nil, status: .notStarted), .intro)
    }

    func testResumesOnSavedStepWhenKeyboardIsAdded() {
        XCTAssertEqual(OnboardingFlow.initialStep(saved: .fullAccess, status: added), .fullAccess)
        XCTAssertEqual(OnboardingFlow.initialStep(saved: .tryKeyboard, status: added), .tryKeyboard)
        XCTAssertEqual(OnboardingFlow.initialStep(saved: .complete, status: added), .complete)
    }

    func testResumeFallsBackToAddKeyboardWhenKeyboardWasRemoved() {
        XCTAssertEqual(OnboardingFlow.initialStep(saved: .fullAccess, status: .notStarted), .addKeyboard)
        XCTAssertEqual(OnboardingFlow.initialStep(saved: .tryKeyboard, status: .notStarted), .addKeyboard)
        XCTAssertEqual(OnboardingFlow.initialStep(saved: .complete, status: .notStarted), .addKeyboard)
    }

    func testFlowIsLinear() {
        XCTAssertEqual(OnboardingFlow.next(after: .intro), .addKeyboard)
        XCTAssertEqual(OnboardingFlow.next(after: .addKeyboard), .fullAccess)
        XCTAssertEqual(OnboardingFlow.next(after: .fullAccess), .tryKeyboard)
        XCTAssertEqual(OnboardingFlow.next(after: .tryKeyboard), .complete)
        XCTAssertEqual(OnboardingFlow.next(after: .complete), .complete)
    }

    func testBackNavigation() {
        XCTAssertNil(OnboardingFlow.previous(before: .intro))
        XCTAssertEqual(OnboardingFlow.previous(before: .addKeyboard), .intro)
        XCTAssertEqual(OnboardingFlow.previous(before: .fullAccess), .addKeyboard)
        XCTAssertEqual(OnboardingFlow.previous(before: .tryKeyboard), .fullAccess)
        XCTAssertNil(OnboardingFlow.previous(before: .complete), "Completion must not be undoable by Back")
    }

    func testSetupStepNumbering() {
        XCTAssertNil(OnboardingStep.intro.setupIndex)
        XCTAssertEqual(OnboardingStep.addKeyboard.setupIndex, 1)
        XCTAssertEqual(OnboardingStep.fullAccess.setupIndex, 2)
        XCTAssertEqual(OnboardingStep.tryKeyboard.setupIndex, 3)
        XCTAssertNil(OnboardingStep.complete.setupIndex)
    }
}

// MARK: - Status detection

final class KeyboardSetupStatusResolverTests: XCTestCase {
    private let resolver = KeyboardSetupStatusResolver(keyboardBundleIdentifier: keyboardID)

    func testNotAddedWhenKeyboardMissingFromList() {
        let status = resolver.resolve(installedKeyboards: ["en_US@sw=QWERTY;hw=Automatic", "emoji@sw=Emoji"], report: .empty)
        XCTAssertEqual(status, .notStarted)
    }

    func testAddedWhenKeyboardListed() {
        let status = resolver.resolve(installedKeyboards: ["en_US@sw=QWERTY;hw=Automatic", keyboardID], report: .empty)
        XCTAssertTrue(status.isKeyboardAdded)
        XCTAssertEqual(status.fullAccess, .unknown, "Full Access is unknown until the keyboard reports in")
        XCTAssertFalse(status.isAIReady)
    }

    func testFullAccessGrantedWhenKeyboardReportsIt() {
        let now = Date()
        let report = KeyboardReport(lastActiveAt: now, hasFullAccess: true, fullAccessReportedAt: now)
        let status = resolver.resolve(installedKeyboards: [keyboardID], report: report)
        XCTAssertEqual(status.fullAccess, .granted)
        XCTAssertTrue(status.isAIReady)
        XCTAssertEqual(status.lastActiveAt, now)
    }

    func testFullAccessDeniedWhenKeyboardReportsIt() {
        let report = KeyboardReport(lastActiveAt: Date(), hasFullAccess: false, fullAccessReportedAt: Date())
        let status = resolver.resolve(installedKeyboards: [keyboardID], report: report)
        XCTAssertEqual(status.fullAccess, .denied)
    }

    func testStaleReportIsIgnoredWhenKeyboardIsNotListed() {
        let report = KeyboardReport(lastActiveAt: Date(), hasFullAccess: true, fullAccessReportedAt: Date())
        let status = resolver.resolve(installedKeyboards: [], report: report)
        XCTAssertEqual(status, .notStarted)
    }

    func testFallsBackToKeyboardActivityWhenListIsUnavailable() {
        XCTAssertFalse(resolver.resolve(installedKeyboards: nil, report: .empty).isKeyboardAdded)

        let report = KeyboardReport(lastActiveAt: Date(), hasFullAccess: true, fullAccessReportedAt: Date())
        XCTAssertTrue(resolver.resolve(installedKeyboards: nil, report: report).isKeyboardAdded)
    }
}

// MARK: - Shared state

final class KeyboardSharedStateTests: XCTestCase {
    func testRoundTrip() {
        let state = KeyboardSharedState(store: InMemoryStore())
        XCTAssertEqual(state.report(), .empty)

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        state.recordKeyboardAppeared(hasFullAccess: true, at: date)

        let report = state.report()
        XCTAssertEqual(report.hasFullAccess, true)
        XCTAssertEqual(report.lastActiveAt, date)
        XCTAssertEqual(report.fullAccessReportedAt, date)

        state.reset()
        XCTAssertEqual(state.report(), .empty)
    }

    func testMissingAppGroupIsHarmless() {
        let state = KeyboardSharedState(store: nil)
        state.recordKeyboardAppeared(hasFullAccess: true)
        XCTAssertEqual(state.report(), .empty)
    }
}

// MARK: - View model

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var sharedStore: InMemoryStore!
    private var settings: SpySettingsOpener!
    private var analytics: SpyAnalytics!

    override func setUp() async throws {
        suiteName = "nk.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        sharedStore = InMemoryStore()
        settings = SpySettingsOpener()
        analytics = SpyAnalytics()
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeMonitor(installed: [String]?) -> KeyboardSetupMonitor {
        KeyboardSetupMonitor(
            installedKeyboards: StubInstalledKeyboards(identifiers: installed),
            sharedState: KeyboardSharedState(store: sharedStore),
            keyboardBundleIdentifier: keyboardID,
            observesSystemEvents: false
        )
    }

    private func makeViewModel(monitor: KeyboardSetupMonitor, onFinish: @escaping () -> Void = {}) -> OnboardingViewModel {
        OnboardingViewModel(
            monitor: monitor,
            store: OnboardingStore(defaults: defaults),
            settings: settings,
            analytics: analytics,
            introPageCount: 3,
            onFinish: onFinish
        )
    }

    func testIntroPagesAdvanceThenEnterSetup() {
        let viewModel = makeViewModel(monitor: makeMonitor(installed: []))
        XCTAssertEqual(viewModel.step, .intro)

        viewModel.continueFromIntro()
        viewModel.continueFromIntro()
        XCTAssertEqual(viewModel.introPage, 2)
        XCTAssertEqual(viewModel.step, .intro)

        viewModel.continueFromIntro()
        XCTAssertEqual(viewModel.step, .addKeyboard)
    }

    func testSkipIntroGoesStraightToSetup() {
        let viewModel = makeViewModel(monitor: makeMonitor(installed: []))
        viewModel.skipIntro()
        XCTAssertEqual(viewModel.step, .addKeyboard)
    }

    func testProgressIsPersistedForResume() {
        let monitor = makeMonitor(installed: [keyboardID])
        let first = makeViewModel(monitor: monitor)
        first.skipIntro()
        first.advance()
        XCTAssertEqual(first.step, .fullAccess)

        let relaunched = makeViewModel(monitor: monitor)
        XCTAssertEqual(relaunched.step, .fullAccess)
    }

    func testOpeningSettingsIsTrackedAndFlagsNotDetected() {
        let viewModel = makeViewModel(monitor: makeMonitor(installed: []))
        viewModel.skipIntro()
        XCTAssertFalse(viewModel.showsKeyboardNotDetected)

        viewModel.openSettings()
        XCTAssertEqual(settings.openCount, 1)
        XCTAssertTrue(viewModel.showsKeyboardNotDetected)
        XCTAssertTrue(analytics.events.contains(.onboardingSettingsOpened(step: "addKeyboard")))
    }

    func testSkippingFullAccessStillReachesTheEnd() {
        let viewModel = makeViewModel(monitor: makeMonitor(installed: [keyboardID]))
        viewModel.skipIntro()
        viewModel.advance()
        viewModel.skipFullAccess()
        XCTAssertEqual(viewModel.step, .tryKeyboard)
        XCTAssertTrue(analytics.events.contains(.onboardingFullAccessSkipped))

        viewModel.advance()
        XCTAssertEqual(viewModel.step, .complete)
    }

    func testFinishMarksOnboardingComplete() {
        var didFinish = false
        let viewModel = makeViewModel(monitor: makeMonitor(installed: [keyboardID]), onFinish: { didFinish = true })
        viewModel.finish()

        XCTAssertTrue(didFinish)
        XCTAssertTrue(OnboardingStore(defaults: defaults).isCompleted)
        XCTAssertNil(OnboardingStore(defaults: defaults).savedStep)
    }

    func testKeyboardActivityAfterEnteringTryStepIsDetected() async {
        let monitor = makeMonitor(installed: [keyboardID])
        let viewModel = makeViewModel(monitor: monitor)
        viewModel.skipIntro()
        viewModel.advance()
        viewModel.advance()
        XCTAssertEqual(viewModel.step, .tryKeyboard)
        XCTAssertFalse(viewModel.isKeyboardActiveNow)

        KeyboardSharedState(store: sharedStore)
            .recordKeyboardAppeared(hasFullAccess: true, at: Date().addingTimeInterval(1))
        monitor.refresh()
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(viewModel.isKeyboardActiveNow)
        XCTAssertEqual(viewModel.status.fullAccess, .granted)
    }
}
