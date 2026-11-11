import SwiftUI

/// Launch screen content, following the Splash board: logo, wordmark, tagline and a
/// progress bar.
///
/// The system launch screen (Info.plist › UILaunchScreen) uses the same background colour,
/// so the hand-off is seamless. The splash is held only briefly — long enough to read the
/// brand, never long enough to feel like waiting.
struct SplashView: View {
    let onFinished: () -> Void

    /// Minimum time the splash stays up. Start-up work in later phases (Firebase, StoreKit
    /// entitlements) should run during this window, not extend it noticeably.
    private let duration: Double = 1.1

    @State private var progress: Double = 0
    @State private var didFinish = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            NKColor.splashBackground.ignoresSafeArea()

            VStack(spacing: NKSpacing.l) {
                NKLogoMark(size: 128)

                VStack(spacing: NKSpacing.xs) {
                    Text(verbatim: "NeuralKey")
                        .nkFont(.display)
                        .foregroundColor(NKColor.textPrimary)
                        .accessibilityLabel(Text("Neural Key"))
                        .accessibilityAddTraits(.isHeader)

                    Text("AI-POWERED TYPING ENGINE")
                        .font(NKTypography.font(.subheadline).weight(.medium))
                        .tracking(1.5)
                        .foregroundColor(NKColor.brandText)
                }
            }
            .offset(y: -NKSpacing.xl)

            VStack(spacing: NKSpacing.s) {
                Spacer()
                HStack {
                    Text("Initializing neural networks…")
                        .nkFont(.footnote)
                        .foregroundColor(NKColor.textSecondary)
                    Spacer()
                    Text(verbatim: "\(Int((progress * 100).rounded()))%")
                        .font(NKTypography.font(.footnote).weight(.semibold))
                        .foregroundColor(NKColor.brandText)
                        .monospacedDigit()
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(NKColor.track)
                        Capsule()
                            .fill(NKColor.brand)
                            .frame(width: max(proxy.size.width * progress, 0))
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, NKSpacing.xl)
            .padding(.bottom, NKSpacing.xxl)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Loading"))
        }
        .task {
            await run()
        }
    }

    private func run() async {
        guard !didFinish else { return }

        if reduceMotion {
            progress = 1
        } else {
            // Step the value so the percentage label counts up with the bar.
            let steps = 22
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(duration / Double(steps) * 1_000_000_000))
                if Task.isCancelled { return }
                withAnimation(.linear(duration: duration / Double(steps))) {
                    progress = Double(step) / Double(steps)
                }
            }
        }

        try? await Task.sleep(nanoseconds: reduceMotion ? 500_000_000 : 120_000_000)
        if Task.isCancelled { return }
        didFinish = true
        onFinished()
    }
}
