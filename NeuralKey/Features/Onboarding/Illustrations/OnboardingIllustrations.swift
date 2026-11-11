import SwiftUI

// Illustrations are drawn in SwiftUI rather than shipped as images: they stay sharp on
// every screen size, follow the design tokens, and can reflect live state (a toggle
// flips on the moment the real setting is detected).

// MARK: - Settings mock (add keyboard / Full Access)

/// A stylised copy of Settings › Neural Key › Keyboards showing the two switches the user
/// needs. The row for the current step is highlighted.
struct SettingsKeyboardsIllustration: View {
    enum Focus {
        case keyboard
        case fullAccess
    }

    let focus: Focus
    let isKeyboardOn: Bool
    let isFullAccessOn: Bool
    /// Compact shows only the focused switch, for steps that need the room for copy.
    var isCompact: Bool = false

    var body: some View {
        if isCompact {
            list
                .shadow(color: NKColor.brand.opacity(0.35), radius: 30, x: 0, y: 12)
                .frame(maxWidth: 300)
                .padding(.horizontal, NKSpacing.xl)
                .frame(maxHeight: .infinity)
        } else {
            list
                .padding(NKSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: NKRadius.card + 4, style: .continuous)
                        .fill(NKColor.surfaceRaised.opacity(0.75))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NKRadius.card + 4, style: .continuous)
                        .stroke(NKColor.border.opacity(0.8), lineWidth: 1)
                )
                .shadow(color: NKColor.brand.opacity(0.35), radius: 30, x: 0, y: 12)
                .frame(maxWidth: 300)
                .padding(.horizontal, NKSpacing.xl)
                .frame(maxHeight: .infinity)
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            HStack(spacing: NKSpacing.xs) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(NKColor.brandText)
                Text("Keyboards")
                    .font(NKTypography.font(.footnote).weight(.semibold))
                    .foregroundColor(NKColor.textPrimary)
                Spacer()
                Text("SETTINGS")
                    .nkFont(.overline)
                    .tracking(1)
                    .foregroundColor(NKColor.textTertiary)
            }
            .padding(.horizontal, NKSpacing.m)
            .frame(height: 40)

            if !isCompact || focus == .keyboard {
                NKDivider()
                row(title: "Neural Key", isOn: isKeyboardOn, isFocused: focus == .keyboard)
            }

            if !isCompact || focus == .fullAccess {
                NKDivider()
                row(title: "Allow Full Access", isOn: isFullAccessOn, isFocused: focus == .fullAccess)
            }
        }
        .background(NKColor.surfaceField)
        .clipShape(RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous)
                .stroke(NKColor.border, lineWidth: 1)
        )
    }

    private func row(title: LocalizedStringKey, isOn: Bool, isFocused: Bool) -> some View {
        HStack {
            Text(title)
                .font(NKTypography.font(.subheadline).weight(isFocused ? .semibold : .regular))
                .foregroundColor(isFocused ? NKColor.textPrimary : NKColor.textSecondary)
            Spacer()
            MockToggle(isOn: isOn, pulses: isFocused && !isOn)
        }
        .padding(.horizontal, NKSpacing.m)
        .frame(height: 48)
        .background(isFocused ? NKColor.surfaceHighlight : Color.clear)
        .overlay(alignment: .leading) {
            if isFocused {
                Rectangle().fill(NKColor.brand).frame(width: 3)
            }
        }
    }
}

/// Non-interactive switch. Pulses to draw the eye to the control the user must turn on.
private struct MockToggle: View {
    let isOn: Bool
    let pulses: Bool

    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? NKColor.brand : Color.white.opacity(0.16))
            Circle()
                .fill(Color.white)
                .padding(2)
        }
        .frame(width: 40, height: 24)
        .background(
            Capsule()
                .stroke(NKColor.brandText, lineWidth: 2)
                .scaleEffect(isPulsing ? 1.5 : 1)
                .opacity(pulses ? (isPulsing ? 0 : 0.9) : 0)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isOn)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Keyboard switcher mock (try it)

/// The globe-key menu from the first onboarding frame: shows where "Neural Key" appears
/// when the user touches and holds the globe.
struct KeyboardSwitcherIllustration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: NKSpacing.xs) {
            VStack(spacing: 0) {
                menuRow(title: "English (US)")
                NKDivider()
                menuRow(title: "Emoji", systemImage: "face.smiling")
                NKDivider()
                menuRow(title: "Neural Key", systemImage: "checkmark", isSelected: true)
            }
            .frame(width: 190)
            .background(NKColor.surfaceField)
            .clipShape(RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous)
                    .stroke(NKColor.border, lineWidth: 1)
            )
            .shadow(color: NKColor.brand.opacity(0.35), radius: 28, x: 0, y: 10)

            HStack(spacing: 6) {
                mockKey(width: 40) {
                    Text("123").font(.system(size: 12, weight: .medium))
                }
                mockKey(width: 40, isHighlighted: true) {
                    Image(systemName: "globe").font(.system(size: 15, weight: .medium))
                }
                mockKey(width: nil) {
                    Text("space").font(.system(size: 12, weight: .medium))
                }
                mockKey(width: 64, fill: NKColor.brand) {
                    Text("return").font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundColor(NKColor.textPrimary)
        }
        .frame(maxWidth: 290)
        .padding(.horizontal, NKSpacing.xl)
        .frame(maxHeight: .infinity)
    }

    private func menuRow(title: LocalizedStringKey, systemImage: String? = nil, isSelected: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(NKTypography.font(.footnote).weight(isSelected ? .semibold : .regular))
            Spacer()
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .foregroundColor(isSelected ? NKColor.brandText : NKColor.textSecondary)
        .padding(.horizontal, NKSpacing.s)
        .frame(height: 38)
        .background(isSelected ? NKColor.surfaceHighlight : Color.clear)
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle().fill(NKColor.brand).frame(width: 3)
            }
        }
    }

    private func mockKey<KeyLabel: View>(
        width: CGFloat?,
        isHighlighted: Bool = false,
        fill: Color = Color.white.opacity(0.10),
        @ViewBuilder label: () -> KeyLabel
    ) -> some View {
        label()
            .frame(maxWidth: width == nil ? .infinity : nil)
            .frame(width: width, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHighlighted ? NKColor.brand.opacity(0.35) : fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isHighlighted ? NKColor.brandText : Color.clear, lineWidth: 1.5)
            )
    }
}

// MARK: - Intro heroes

/// Before/after message bubbles that show each feature rather than describe it.
struct IntroHeroView: View {
    let kind: IntroPage.Kind

    var body: some View {
        VStack(spacing: NKSpacing.s) {
            switch kind {
            case .improve:
                bubble("i has went to office yesterday", isResult: false, isStruckThrough: true)
                connector(systemImage: "wand.and.stars", label: "Improve")
                bubble("I went to the office yesterday.", isResult: true, badge: "Grammar fixed")
            case .translate:
                bubble("See you tomorrow at 3 pm.", isResult: false)
                connector(systemImage: "arrow.left.arrow.right", label: "EN → ES")
                bubble("Nos vemos mañana a las 3 p. m.", isResult: true, badge: "Translated")
            case .tone:
                bubble("send me the file asap", isResult: false)
                connector(systemImage: "slider.horizontal.3", label: "Professional")
                bubble("Could you please send me the file at your earliest convenience?", isResult: true, badge: "Tone adjusted")
            }
        }
        .frame(maxWidth: 300)
        .padding(.horizontal, NKSpacing.xl)
        .frame(maxHeight: .infinity)
    }

    private func bubble(
        _ text: String,
        isResult: Bool,
        isStruckThrough: Bool = false,
        badge: LocalizedStringKey? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: NKSpacing.xs) {
            if let badge = badge {
                HStack(spacing: 6) {
                    Circle().fill(NKColor.success).frame(width: 6, height: 6)
                    Text(badge)
                        .nkFont(.overline)
                        .foregroundColor(NKColor.textPrimary)
                }
            }
            Text(verbatim: text)
                .nkFont(.subheadline)
                .foregroundColor(isResult ? NKColor.textPrimary : NKColor.textSecondary)
                .strikethrough(isStruckThrough, color: NKColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NKSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous)
                .fill(isResult ? NKColor.surfaceRaised : NKColor.surfaceField.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous)
                .stroke(isResult ? NKColor.brand : NKColor.border, lineWidth: isResult ? 1.5 : 1)
        )
        .shadow(color: NKColor.brand.opacity(isResult ? 0.35 : 0), radius: 22, x: 0, y: 8)
    }

    private func connector(systemImage: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(verbatim: label)
                .nkFont(.caption)
        }
        .foregroundColor(.white)
        .padding(.horizontal, NKSpacing.s)
        .frame(height: 26)
        .background(Capsule().fill(NKColor.brand))
    }
}

// MARK: - Completion

struct SetupCompleteIllustration: View {
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NKLogoMark(size: 112)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.white, NKColor.success)
                .background(Circle().fill(NKColor.background).padding(3))
                .offset(x: 10, y: 10)
                .scaleEffect(isVisible ? 1 : 0.4)
                .opacity(isVisible ? 1 : 0)
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.15)) {
                    isVisible = true
                }
            }
        }
    }
}
