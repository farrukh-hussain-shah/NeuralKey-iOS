import UIKit

/// Neural Key custom keyboard (Phase 1 baseline).
///
/// Responsibilities in this phase:
///  • a reliable QWERTY keyboard that works with or without Full Access;
///  • telling the containing app that the keyboard is in use and whether Full Access is
///    on, so onboarding can confirm setup;
///  • a quiet notice when Full Access is off, since AI features will need it.
///
/// Notes on iOS behaviour this code relies on:
///  • iOS never shows third-party keyboards in secure (password) fields, so no typed
///    password can reach this extension.
///  • `hasFullAccess` is the source of truth for network use. Every AI request added in
///    Phase 2 must check it at call time.
final class KeyboardViewController: UIInputViewController {
    private let sharedState = KeyboardSharedState()
    private let keyboardView = KeyboardView()
    private var heightConstraint: NSLayoutConstraint?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        keyboardView.delegate = self
        keyboardView.onKeysRebuilt = { [weak self] in self?.attachGlobeAction() }
        // Keys are first built in KeyboardView.init, before the callback above exists.
        attachGlobeAction()
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)

        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureKeyboard()
        updateAutoShift()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reportStatusToApp()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        configureKeyboard()
        updateAutoShift()
    }

    // MARK: Configuration

    private func configureKeyboard() {
        keyboardView.configure(
            showsGlobe: needsInputModeSwitchKey,
            showsFullAccessNotice: !hasFullAccess,
            returnTitle: returnKeyTitle
        )
        applyHeight(keyboardView.preferredHeight)
    }

    private func applyHeight(_ height: CGFloat) {
        if let heightConstraint = heightConstraint {
            if heightConstraint.constant != height {
                heightConstraint.constant = height
            }
            return
        }
        let constraint = view.heightAnchor.constraint(equalToConstant: height)
        // Below "required" so it never fights the system's own constraints during rotation.
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        heightConstraint = constraint
    }

    private func attachGlobeAction() {
        // Apple requires the globe key to use this exact selector: tap switches to the next
        // keyboard, touch-and-hold shows the keyboard list.
        keyboardView.globeButton?.addTarget(
            self,
            action: #selector(handleInputModeList(from:with:)),
            for: .allTouchEvents
        )
    }

    private var returnKeyTitle: String {
        switch textDocumentProxy.returnKeyType ?? .default {
        case .go: return "go"
        case .search, .google, .yahoo: return "search"
        case .send: return "send"
        case .next: return "next"
        case .done: return "done"
        case .join: return "join"
        case .continue: return "continue"
        default: return "return"
        }
    }

    // MARK: App Group status

    /// Tells the containing app the keyboard is live and whether Full Access is on.
    /// Without Full Access iOS blocks the shared container, so the write is a silent no-op
    /// and the app keeps showing "not confirmed" — which is the correct state.
    private func reportStatusToApp() {
        sharedState.recordKeyboardAppeared(hasFullAccess: hasFullAccess)
        DarwinNotifier.post(.keyboardStateChanged)
    }

    // MARK: Auto-capitalisation

    private func updateAutoShift() {
        keyboardView.setAutoShift(shouldAutoCapitalize)
    }

    private var shouldAutoCapitalize: Bool {
        let proxy = textDocumentProxy
        switch proxy.autocapitalizationType ?? .sentences {
        case .none:
            return false
        case .allCharacters:
            return true
        case .words:
            guard let before = proxy.documentContextBeforeInput, let last = before.last else { return true }
            return last == " " || last == "\n"
        case .sentences:
            guard let before = proxy.documentContextBeforeInput, !before.isEmpty else { return true }
            if before.hasSuffix("\n") { return true }
            let trimmed = before.trimmingCharacters(in: .whitespaces)
            guard before.hasSuffix(" "), let last = trimmed.last else { return false }
            return last == "." || last == "!" || last == "?"
        @unknown default:
            return false
        }
    }
}

// MARK: - KeyboardViewDelegate

extension KeyboardViewController: KeyboardViewDelegate {
    func keyboardView(_ keyboardView: KeyboardView, didInsert text: String) {
        textDocumentProxy.insertText(text)
        updateAutoShift()
    }

    func keyboardViewDidDeleteBackward(_ keyboardView: KeyboardView) {
        textDocumentProxy.deleteBackward()
        updateAutoShift()
    }

    func keyboardViewDidPressReturn(_ keyboardView: KeyboardView) {
        textDocumentProxy.insertText("\n")
        updateAutoShift()
    }
}
