import SwiftUI

/// One feature page in the intro pager.
struct IntroPage: Identifiable {
    enum Kind {
        case improve
        case translate
        case tone
    }

    let id: Int
    let kind: Kind
    let titleLine1: LocalizedStringKey
    let titleLine2: LocalizedStringKey
    let message: LocalizedStringKey

    /// The three core features, in the order the product leads with them.
    static let all: [IntroPage] = [
        IntroPage(
            id: 0,
            kind: .improve,
            titleLine1: "Your English is good.",
            titleLine2: "Now make it better.",
            message: "Fix grammar, spelling and clarity in one tap, right where you type."
        ),
        IntroPage(
            id: 1,
            kind: .translate,
            titleLine1: "Say it in",
            titleLine2: "any language",
            message: "Translate your message naturally without leaving the app you're in."
        ),
        IntroPage(
            id: 2,
            kind: .tone,
            titleLine1: "Sound right,",
            titleLine2: "every time",
            message: "Switch between professional, friendly and casual while keeping your meaning."
        )
    ]
}

/// Swipeable introduction to Improve, Translate and Tone.
struct IntroPagerView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private let pages = IntroPage.all

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { viewModel.skipIntro() }
                    .font(NKTypography.font(.subheadline).weight(.medium))
                    .foregroundColor(NKColor.textSecondary)
                    .frame(minWidth: NKSize.minTapTarget, minHeight: NKSize.minTapTarget)
                    .contentShape(Rectangle())
                    .accessibilityHint(Text("Goes straight to keyboard setup"))
            }
            .padding(.horizontal, NKSpacing.m)
            .frame(height: OnboardingTopBar.height)

            TabView(selection: $viewModel.introPage) {
                ForEach(pages) { page in
                    IntroPageView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            footer
        }
    }

    private var primaryTitle: LocalizedStringKey {
        viewModel.isLastIntroPage ? "Set Up Keyboard" : "Continue"
    }

    private var footer: some View {
        VStack(spacing: NKSpacing.m) {
            NKPageIndicator(count: pages.count, current: viewModel.introPage)

            Button {
                viewModel.continueFromIntro()
            } label: {
                Text(primaryTitle)
            }
            .buttonStyle(.nkPrimary)

            Text(Self.legalText)
                .nkFont(.caption)
                .foregroundColor(NKColor.textTertiary)
                .tint(NKColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, NKSpacing.l)
        .padding(.top, NKSpacing.xs)
        .padding(.bottom, NKSpacing.s)
        .frame(maxWidth: .infinity)
        .background(NKColor.surface.ignoresSafeArea(edges: .bottom))
    }

    private static let legalText: AttributedString = {
        let markdown = "By continuing, you agree to our [Terms](\(AppLinks.termsOfUse.absoluteString)) and [Privacy Policy](\(AppLinks.privacyPolicy.absoluteString))."
        if let attributed = try? AttributedString(markdown: markdown) {
            return attributed
        }
        return AttributedString("By continuing, you agree to our Terms and Privacy Policy.")
    }()
}

private struct IntroPageView: View {
    let page: IntroPage

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    IntroHeroView(kind: page.kind)
                        .frame(maxWidth: .infinity)
                        .frame(height: min(max(proxy.size.height * 0.48, 180), 340))
                        .accessibilityHidden(true)

                    VStack(spacing: NKSpacing.m) {
                        NKTwoToneTitle(line1: page.titleLine1, line2: page.titleLine2)

                        Text(page.message)
                            .nkFont(.body)
                            .foregroundColor(NKColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(alignment: .top, spacing: NKSpacing.xs) {
                            NKFeatureChip(systemImage: "lock.shield", title: "Private", subtitle: "Typing stays local")
                            NKFeatureChip(systemImage: "bolt", title: "Fast", subtitle: "One-tap rewrites")
                            NKFeatureChip(systemImage: "square.grid.2x2", title: "Any app", subtitle: "Where you type")
                        }
                        .padding(.top, NKSpacing.xxs)
                    }
                    .padding(.horizontal, NKSpacing.l)
                    .padding(.top, NKSpacing.xl)
                    .padding(.bottom, NKSpacing.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(
                        TopRoundedRectangle()
                            .fill(NKColor.surface)
                            .overlay(TopRoundedOutline().stroke(NKColor.borderSubtle, lineWidth: 1))
                    )
                }
                .frame(minHeight: proxy.size.height)
            }
        }
    }
}
