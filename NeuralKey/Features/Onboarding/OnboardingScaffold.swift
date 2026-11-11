import SwiftUI

/// Shared layout for every setup step, taken from the onboarding board:
/// an illustration on the glow background, then a bottom sheet with the copy and actions.
///
/// - The hero shrinks on small phones and disappears when `isHeroCollapsed` is true
///   (used while the keyboard is on screen).
/// - Copy scrolls, so large Dynamic Type sizes and iPhone SE never clip.
/// - Actions are pinned to the bottom so the primary button is always reachable.
/// How much vertical space the illustration gets.
enum OnboardingHeroSize {
    /// Default: roughly a third of the screen.
    case regular
    /// For copy-heavy steps (Full Access) so the whole explanation fits without scrolling
    /// on a standard iPhone.
    case compact

    func height(in available: CGFloat) -> CGFloat {
        switch self {
        case .regular: return min(max(available * 0.36, 170), 320)
        case .compact: return min(max(available * 0.16, 104), 140)
        }
    }
}

struct OnboardingScaffold<Hero: View, Content: View, Footer: View>: View {
    var topBar: OnboardingTopBar?
    var heroSize: OnboardingHeroSize = .regular
    var isHeroCollapsed: Bool = false
    @ViewBuilder var hero: () -> Hero
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = isHeroCollapsed ? 0 : heroSize.height(in: proxy.size.height)

            VStack(spacing: 0) {
                if let topBar = topBar {
                    topBar
                } else {
                    Color.clear.frame(height: OnboardingTopBar.height)
                }

                hero()
                    .frame(maxWidth: .infinity)
                    .frame(height: heroHeight)
                    .opacity(isHeroCollapsed ? 0 : 1)
                    .clipped()
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        content()
                            .padding(.horizontal, NKSpacing.l)
                            .padding(.top, NKSpacing.xl)
                            .padding(.bottom, NKSpacing.m)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    footer()
                        .padding(.horizontal, NKSpacing.l)
                        .padding(.top, NKSpacing.xs)
                        .padding(.bottom, NKSpacing.s)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    TopRoundedRectangle()
                        .fill(NKColor.surface)
                        .overlay(TopRoundedRectangle().stroke(NKColor.borderSubtle, lineWidth: 1))
                        .ignoresSafeArea(edges: .bottom)
                )
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isHeroCollapsed)
        }
    }
}

/// Back button, "Step n of 3" progress and Help. Sits above the hero on every setup step.
struct OnboardingTopBar: View {
    static let height: CGFloat = 52

    let step: OnboardingStep
    var onBack: (() -> Void)?
    var onHelp: (() -> Void)?

    var body: some View {
        HStack {
            if let onBack = onBack {
                NKIconButton(systemImage: "chevron.left", accessibilityLabel: "Back", action: onBack)
            } else {
                Color.clear.frame(width: NKSize.minTapTarget, height: NKSize.minTapTarget)
            }

            Spacer()

            if let index = step.setupIndex {
                SetupProgressView(current: index, total: OnboardingStep.setupStepCount)
            }

            Spacer()

            if let onHelp = onHelp {
                Button(action: onHelp) {
                    Text("Help")
                        .font(NKTypography.font(.subheadline).weight(.medium))
                        .foregroundColor(NKColor.brandText)
                        .frame(minWidth: NKSize.minTapTarget, minHeight: NKSize.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens setup troubleshooting"))
            } else {
                Color.clear.frame(width: NKSize.minTapTarget, height: NKSize.minTapTarget)
            }
        }
        .padding(.horizontal, NKSpacing.s)
        .frame(height: Self.height)
    }
}

/// Three segments showing how far through setup the user is.
struct SetupProgressView: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(spacing: 6) {
            Text("STEP \(current) OF \(total)")
                .nkFont(.overline)
                .tracking(1.2)
                .foregroundColor(NKColor.textSecondary)
            HStack(spacing: 4) {
                ForEach(1...total, id: \.self) { index in
                    Capsule()
                        .fill(index <= current ? NKColor.brand : NKColor.track)
                        .frame(width: 28, height: 4)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Step \(current) of \(total)"))
    }
}

/// Pinned actions under the sheet content: one primary button and an optional secondary.
struct OnboardingActions: View {
    let primaryTitle: LocalizedStringKey
    var primarySystemImage: String?
    let primaryAction: () -> Void
    var secondaryTitle: LocalizedStringKey?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: NKSpacing.xxs) {
            Button(action: primaryAction) {
                HStack(spacing: NKSpacing.xs) {
                    Text(primaryTitle)
                    if let primarySystemImage = primarySystemImage {
                        Image(systemName: primarySystemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(.nkPrimary)

            if let secondaryTitle = secondaryTitle, let secondaryAction = secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.nkText)
            }
        }
    }
}
