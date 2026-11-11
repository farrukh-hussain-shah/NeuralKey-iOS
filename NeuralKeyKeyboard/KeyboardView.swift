import UIKit

// Phase 1 baseline keyboard: a dependable QWERTY so setup can be completed and verified
// end to end. The AI toolbar (Improve / Translate / Tone / Clipboard) from the
// "Toolbar actions" boards is built on top of this in Phase 2.
//
// Built with plain UIKit and manual layout on purpose: keyboard extensions have a tight
// memory budget and must appear instantly.

// MARK: - Model

enum KeyboardPage {
    case letters
    case numbers
    case symbols
}

enum ShiftState {
    case off
    case on
    case locked
}

enum KeyKind: Equatable {
    case character(String)
    case shift
    case backspace
    case page(KeyboardPage)
    case globe
    case space
    case returnKey
}

protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ keyboardView: KeyboardView, didInsert text: String)
    func keyboardViewDidDeleteBackward(_ keyboardView: KeyboardView)
    func keyboardViewDidPressReturn(_ keyboardView: KeyboardView)
}

// MARK: - Appearance

/// Colours sampled from the "Toolbar actions" boards.
enum KeyboardPalette {
    static let background = UIColor(red: 0x14 / 255, green: 0x12 / 255, blue: 0x18 / 255, alpha: 1)
    static let key = UIColor(red: 0x2B / 255, green: 0x29 / 255, blue: 0x30 / 255, alpha: 1)
    static let specialKey = UIColor(red: 0x3C / 255, green: 0x3A / 255, blue: 0x42 / 255, alpha: 1)
    static let action = UIColor(red: 0x0F / 255, green: 0x5A / 255, blue: 0xF3 / 255, alpha: 1)
    static let text = UIColor.white
    static let secondaryText = UIColor(white: 1, alpha: 0.6)
    static let pressed = UIColor(white: 1, alpha: 0.28)
}

// MARK: - Key button

final class KeyButton: UIButton {
    let kind: KeyKind
    /// Relative width within its row (1 = one letter key).
    let widthUnits: CGFloat
    private let restingColor: UIColor

    init(kind: KeyKind, widthUnits: CGFloat = 1) {
        self.kind = kind
        self.widthUnits = widthUnits
        switch kind {
        case .character, .space:
            restingColor = KeyboardPalette.key
        case .returnKey:
            restingColor = KeyboardPalette.action
        case .shift, .backspace, .page, .globe:
            restingColor = KeyboardPalette.specialKey
        }
        super.init(frame: .zero)
        backgroundColor = restingColor
        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
        tintColor = KeyboardPalette.text
        setTitleColor(KeyboardPalette.text, for: .normal)
        isExclusiveTouch = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? KeyboardPalette.pressed : restingColor
        }
    }

    func setSymbol(_ name: String, pointSize: CGFloat = 18) {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        setImage(UIImage(systemName: name, withConfiguration: configuration), for: .normal)
        setTitle(nil, for: .normal)
    }

    func setLabel(_ text: String, size: CGFloat) {
        setImage(nil, for: .normal)
        setTitle(text, for: .normal)
        titleLabel?.font = .systemFont(ofSize: size, weight: .regular)
    }
}

// MARK: - Row

/// Lays keys out proportionally to their `widthUnits`. `sideInsetUnits` indents the row
/// (the "asdf" row is inset by half a key on each side).
final class KeyRowView: UIView {
    static let spacing: CGFloat = 6

    var sideInsetUnits: CGFloat = 0
    private(set) var keys: [KeyButton] = []

    func setKeys(_ newKeys: [KeyButton], sideInsetUnits: CGFloat = 0) {
        keys.forEach { $0.removeFromSuperview() }
        keys = newKeys
        self.sideInsetUnits = sideInsetUnits
        newKeys.forEach { addSubview($0) }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !keys.isEmpty else { return }
        let totalUnits = keys.reduce(0) { $0 + $1.widthUnits } + sideInsetUnits * 2
        let totalSpacing = Self.spacing * CGFloat(keys.count - 1)
        let unit = max((bounds.width - totalSpacing) / totalUnits, 0)
        var x = sideInsetUnits * unit
        for key in keys {
            let width = key.widthUnits * unit
            key.frame = CGRect(x: x, y: 0, width: width, height: bounds.height).integral
            x += width + Self.spacing
        }
    }
}

// MARK: - Keyboard

final class KeyboardView: UIView {
    static let rowHeight: CGFloat = 44
    static let rowSpacing: CGFloat = 10
    static let noticeHeight: CGFloat = 30
    static let verticalPadding: CGFloat = 8

    weak var delegate: KeyboardViewDelegate?

    /// The globe key. The controller wires this to `handleInputModeList(from:with:)`.
    private(set) var globeButton: KeyButton?

    private var page: KeyboardPage = .letters
    private(set) var shiftState: ShiftState = .off
    private var showsGlobe = true
    private var showsNotice = false
    private var returnTitle = "return"
    private var lastShiftTap = Date.distantPast
    private var deleteTimer: Timer?

    private let rows = [KeyRowView(), KeyRowView(), KeyRowView(), KeyRowView()]
    private let noticeLabel = UILabel()

    /// Called whenever keys are rebuilt so the controller can re-attach the globe action.
    var onKeysRebuilt: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyboardPalette.background

        noticeLabel.text = "AI features need Full Access  ·  Settings › Neural Key › Keyboards"
        noticeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        noticeLabel.textColor = KeyboardPalette.secondaryText
        noticeLabel.textAlignment = .center
        noticeLabel.adjustsFontSizeToFitWidth = true
        noticeLabel.minimumScaleFactor = 0.7
        noticeLabel.isHidden = true
        addSubview(noticeLabel)

        rows.forEach { addSubview($0) }
        rebuildKeys()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        deleteTimer?.invalidate()
    }

    // MARK: Configuration

    /// Total height the keyboard needs for the current configuration.
    var preferredHeight: CGFloat {
        let rowsHeight = Self.rowHeight * 4 + Self.rowSpacing * 3
        return rowsHeight + Self.verticalPadding * 2 + (showsNotice ? Self.noticeHeight : 0)
    }

    /// Safe to call on every text change: keys are only rebuilt when something differs,
    /// so a touch that is already in progress is never cancelled mid-typing.
    func configure(showsGlobe: Bool, showsFullAccessNotice: Bool, returnTitle: String) {
        let needsRebuild = showsGlobe != self.showsGlobe || returnTitle != self.returnTitle
        let needsLayout = showsFullAccessNotice != showsNotice

        self.showsGlobe = showsGlobe
        self.showsNotice = showsFullAccessNotice
        self.returnTitle = returnTitle
        noticeLabel.isHidden = !showsFullAccessNotice

        if needsRebuild {
            rebuildKeys()
        }
        if needsRebuild || needsLayout {
            setNeedsLayout()
        }
    }

    /// Used by the controller for auto-capitalisation. Never overrides caps lock.
    func setAutoShift(_ isOn: Bool) {
        guard page == .letters, shiftState != .locked else { return }
        let newState: ShiftState = isOn ? .on : .off
        guard newState != shiftState else { return }
        shiftState = newState
        applyShiftAppearance()
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let horizontalPadding: CGFloat = 4
        var y = Self.verticalPadding
        if showsNotice {
            noticeLabel.frame = CGRect(x: 8, y: 2, width: bounds.width - 16, height: Self.noticeHeight)
            y += Self.noticeHeight
        }
        for row in rows {
            row.frame = CGRect(
                x: horizontalPadding,
                y: y,
                width: bounds.width - horizontalPadding * 2,
                height: Self.rowHeight
            )
            y += Self.rowHeight + Self.rowSpacing
        }
    }

    // MARK: Building keys

    private func characterRows() -> [[String]] {
        switch page {
        case .letters:
            // Always lowercase here; case is applied in place by `applyShiftAppearance()`.
            return [
                ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                ["z", "x", "c", "v", "b", "n", "m"]
            ]
        case .numbers:
            return [
                ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
                ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
                [".", ",", "?", "!", "'"]
            ]
        case .symbols:
            return [
                ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
                ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"],
                [".", ",", "?", "!", "'"]
            ]
        }
    }

    private func rebuildKeys() {
        let characters = characterRows()

        rows[0].setKeys(characters[0].map { makeCharacterKey($0, widthUnits: 1) })
        rows[1].setKeys(
            characters[1].map { makeCharacterKey($0, widthUnits: 1) },
            sideInsetUnits: page == .letters ? 0.5 : 0
        )

        // Third row: modifier, characters, backspace.
        let leading: KeyButton
        switch page {
        case .letters:
            leading = KeyButton(kind: .shift, widthUnits: 1.4)
            leading.accessibilityLabel = "Shift"
        case .numbers:
            leading = KeyButton(kind: .page(.symbols), widthUnits: 1.4)
            leading.setLabel("#+=", size: 15)
            leading.accessibilityLabel = "Symbols"
        case .symbols:
            leading = KeyButton(kind: .page(.numbers), widthUnits: 1.4)
            leading.setLabel("123", size: 15)
            leading.accessibilityLabel = "Numbers"
        }
        attach(leading)

        let backspace = KeyButton(kind: .backspace, widthUnits: 1.4)
        backspace.setSymbol("delete.left")
        backspace.accessibilityLabel = "Delete"
        backspace.addTarget(self, action: #selector(backspaceDown), for: .touchDown)
        backspace.addTarget(self, action: #selector(backspaceUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        let middleUnits: CGFloat = page == .letters ? 1 : 1.4
        let middle = characters[2].map { makeCharacterKey($0, widthUnits: middleUnits) }
        rows[2].setKeys([leading] + middle + [backspace])

        // Bottom row.
        var bottom: [KeyButton] = []

        let pageKey = KeyButton(kind: .page(page == .letters ? .numbers : .letters), widthUnits: 1.5)
        pageKey.setLabel(page == .letters ? "123" : "ABC", size: 15)
        pageKey.accessibilityLabel = page == .letters ? "Numbers" : "Letters"
        attach(pageKey)
        bottom.append(pageKey)

        if showsGlobe {
            let globe = KeyButton(kind: .globe, widthUnits: 1.2)
            globe.setSymbol("globe")
            globe.accessibilityLabel = "Next keyboard"
            globeButton = globe
            bottom.append(globe)
        } else {
            globeButton = nil
        }

        let space = KeyButton(kind: .space, widthUnits: showsGlobe ? 5 : 6.2)
        space.setLabel("space", size: 15)
        space.setTitleColor(KeyboardPalette.secondaryText, for: .normal)
        space.accessibilityLabel = "Space"
        attach(space)
        bottom.append(space)

        let returnKey = KeyButton(kind: .returnKey, widthUnits: 2.3)
        returnKey.setLabel(returnTitle, size: 15)
        returnKey.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        returnKey.titleLabel?.adjustsFontSizeToFitWidth = true
        returnKey.accessibilityLabel = returnTitle
        attach(returnKey)
        bottom.append(returnKey)

        rows[3].setKeys(bottom)
        applyShiftAppearance()
        onKeysRebuilt?()
    }

    /// Updates letter case and the shift glyph on the existing keys, without recreating
    /// them, so fast typing is never interrupted.
    private func applyShiftAppearance() {
        guard page == .letters else { return }
        let isUppercase = shiftState != .off
        for row in rows {
            for key in row.keys {
                switch key.kind {
                case .character(let character):
                    let label = isUppercase ? character.uppercased() : character
                    key.setLabel(label, size: 22)
                    key.accessibilityLabel = label
                case .shift:
                    switch shiftState {
                    case .off: key.setSymbol("shift")
                    case .on: key.setSymbol("shift.fill")
                    case .locked: key.setSymbol("capslock.fill")
                    }
                case .backspace, .page, .globe, .space, .returnKey:
                    break
                }
            }
        }
    }

    private func makeCharacterKey(_ character: String, widthUnits: CGFloat) -> KeyButton {
        let key = KeyButton(kind: .character(character), widthUnits: widthUnits)
        key.setLabel(character, size: 22)
        key.accessibilityLabel = character
        attach(key)
        return key
    }

    private func attach(_ key: KeyButton) {
        key.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
    }

    // MARK: Actions

    @objc private func keyTapped(_ sender: KeyButton) {
        switch sender.kind {
        case .character(let character):
            let isUppercase = page == .letters && shiftState != .off
            delegate?.keyboardView(self, didInsert: isUppercase ? character.uppercased() : character)
            if shiftState == .on {
                shiftState = .off
                applyShiftAppearance()
            }
        case .space:
            delegate?.keyboardView(self, didInsert: " ")
        case .returnKey:
            delegate?.keyboardViewDidPressReturn(self)
        case .shift:
            toggleShift()
        case .page(let newPage):
            page = newPage
            rebuildKeys()
        case .backspace, .globe:
            break
        }
    }

    private func toggleShift() {
        let now = Date()
        let isDoubleTap = now.timeIntervalSince(lastShiftTap) < 0.35
        lastShiftTap = now

        switch shiftState {
        case .off:
            shiftState = .on
        case .on:
            shiftState = isDoubleTap ? .locked : .off
        case .locked:
            shiftState = .off
        }
        applyShiftAppearance()
    }

    @objc private func backspaceDown() {
        delegate?.keyboardViewDidDeleteBackward(self)
        deleteTimer?.invalidate()
        // Hold to repeat: short delay, then a steady rate.
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            self?.deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.keyboardViewDidDeleteBackward(self)
            }
        }
    }

    @objc private func backspaceUp() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }
}
