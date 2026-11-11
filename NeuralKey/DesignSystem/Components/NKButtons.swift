import SwiftUI

/// Full-width primary action. One per screen.
struct NKPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NKTypography.font(.headline))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: NKSize.primaryButtonHeight)
            .padding(.horizontal, NKSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous)
                    .fill(NKColor.brand)
            )
            .shadow(color: NKColor.brand.opacity(isEnabled ? 0.35 : 0), radius: 16, x: 0, y: 6)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Low-emphasis text action used under the primary button ("Not now", "Open Settings again").
struct NKTextButtonStyle: ButtonStyle {
    var color: Color = NKColor.textSecondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NKTypography.font(.subheadline).weight(.medium))
            .foregroundColor(color)
            .frame(maxWidth: .infinity, minHeight: NKSize.minTapTarget)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

/// Circular icon button for top bars (back, close). 44pt tap target.
struct NKIconButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(NKColor.textPrimary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .frame(width: NKSize.minTapTarget, height: NKSize.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

extension ButtonStyle where Self == NKPrimaryButtonStyle {
    static var nkPrimary: NKPrimaryButtonStyle { NKPrimaryButtonStyle() }
}

extension ButtonStyle where Self == NKTextButtonStyle {
    static var nkText: NKTextButtonStyle { NKTextButtonStyle() }
    static var nkTextAccent: NKTextButtonStyle { NKTextButtonStyle(color: NKColor.brandText) }
}
