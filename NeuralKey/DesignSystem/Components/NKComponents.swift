import SwiftUI
import UIKit

// MARK: - Background

/// Near-black canvas with the navy glow at the top, as on the Onboarding and Home boards.
struct NKBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            NKColor.background
            RadialGradient(
                colors: [NKColor.backgroundGlow.opacity(0.9), NKColor.backgroundGlow.opacity(0)],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
            .frame(height: 520)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Shapes

/// Rectangle with only the top corners rounded (bottom sheet surface).
struct TopRoundedRectangle: Shape {
    var radius: CGFloat = NKRadius.sheet

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

/// Hairline separator in the border colour.
struct NKDivider: View {
    var body: some View {
        Rectangle()
            .fill(NKColor.border)
            .frame(height: 1)
    }
}

// MARK: - Two-tone title

/// The boards' heading pattern: a white first line and a blue second line.
struct NKTwoToneTitle: View {
    let line1: LocalizedStringKey
    let line2: LocalizedStringKey

    var body: some View {
        VStack(spacing: 2) {
            Text(line1).foregroundColor(NKColor.textPrimary)
            Text(line2).foregroundColor(NKColor.brandText)
        }
        .nkFont(.title)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Feature chip

/// Small three-up benefit tile from the onboarding board.
struct NKFeatureChip: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(NKColor.brandText)
                .frame(height: 22)
            Text(title)
                .nkFont(.caption)
                .foregroundColor(NKColor.textPrimary)
            Text(subtitle)
                .font(NKTypography.font(.overline).weight(.regular))
                .foregroundColor(NKColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NKSpacing.s)
        .padding(.horizontal, NKSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: NKRadius.chip, style: .continuous)
                .fill(NKColor.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NKRadius.chip, style: .continuous)
                .stroke(NKColor.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Page indicator

/// Dots with an elongated active pill, as on the onboarding board.
struct NKPageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? NKColor.brand : NKColor.textTertiary.opacity(0.6))
                    .frame(width: index == current ? 22 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(current + 1) of \(count)"))
    }
}

// MARK: - Numbered instruction

struct NKNumberedStep: View {
    let number: Int
    let text: LocalizedStringKey
    var isDone: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: NKSpacing.s) {
            ZStack {
                Circle()
                    .fill(isDone ? NKColor.success.opacity(0.18) : NKColor.brand.opacity(0.18))
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(NKColor.success)
                } else {
                    Text("\(number)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(NKColor.brandText)
                }
            }
            .frame(width: 24, height: 24)
            .alignmentGuide(.firstTextBaseline) { dimensions in dimensions[.bottom] - 6 }
            .accessibilityHidden(true)

            Text(text)
                .nkFont(.body)
                .foregroundColor(NKColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Step \(number)") + Text(". ") + Text(text))
    }
}

// MARK: - Status banner

/// Inline state message: success, warning or neutral information.
struct NKStatusBanner: View {
    enum Kind {
        case success
        case warning
        case info

        var color: Color {
            switch self {
            case .success: return NKColor.success
            case .warning: return NKColor.warning
            case .info: return NKColor.brandText
            }
        }

        var systemImage: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    let kind: Kind
    let title: LocalizedStringKey
    var message: LocalizedStringKey?

    var body: some View {
        HStack(alignment: .top, spacing: NKSpacing.s) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(kind.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NKTypography.font(.subheadline).weight(.semibold))
                    .foregroundColor(NKColor.textPrimary)
                if let message = message {
                    Text(message)
                        .nkFont(.footnote)
                        .foregroundColor(NKColor.textSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(NKSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous)
                .fill(kind.color.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous)
                .stroke(kind.color.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Info row

/// Icon + title + supporting line, used to explain permissions and tips.
struct NKInfoRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var tint: Color = NKColor.brandText

    var body: some View {
        HStack(alignment: .top, spacing: NKSpacing.s) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.14))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NKTypography.font(.subheadline).weight(.semibold))
                    .foregroundColor(NKColor.textPrimary)
                Text(message)
                    .nkFont(.footnote)
                    .foregroundColor(NKColor.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Card

struct NKCardModifier: ViewModifier {
    var padding: CGFloat = NKSpacing.m

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: NKRadius.card, style: .continuous)
                    .fill(NKColor.surfaceRaised.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NKRadius.card, style: .continuous)
                    .stroke(NKColor.borderSubtle, lineWidth: 1)
            )
    }
}

extension View {
    func nkCard(padding: CGFloat = NKSpacing.m) -> some View {
        modifier(NKCardModifier(padding: padding))
    }
}

// MARK: - Logo

struct NKLogoMark: View {
    var size: CGFloat = 96
    var glow: Bool = true

    var body: some View {
        Image("LogoMark")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.235, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.235, style: .continuous)
                    .stroke(NKColor.brand.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: NKColor.brand.opacity(glow ? 0.55 : 0), radius: size * 0.28, x: 0, y: 0)
            .accessibilityHidden(true)
    }
}
