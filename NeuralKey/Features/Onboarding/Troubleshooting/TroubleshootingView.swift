import SwiftUI

/// Setup help, reachable from every setup step (and later from Settings).
/// Answers the questions that stop people finishing keyboard setup, and always offers
/// the manual Settings path and a way to reach support.
struct TroubleshootingView: View {
    let status: KeyboardSetupStatus
    let onOpenSettings: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private struct Topic: Identifiable {
        let id: Int
        let question: LocalizedStringKey
        let answer: LocalizedStringKey
    }

    private let topics: [Topic] = [
        Topic(
            id: 0,
            question: "I can't find Neural Key in Settings",
            answer: "Open the Settings app and go to **General › Keyboard › Keyboards › Add New Keyboard…**, then choose **Neural Key** under Third-Party Keyboards. If it isn't listed, restart your iPhone and look again."
        ),
        Topic(
            id: 1,
            question: "There's no Allow Full Access switch",
            answer: "Add the keyboard first. Then go to **Settings › General › Keyboard › Keyboards › Neural Key** and turn on **Allow Full Access**. On a work or school iPhone, or with Screen Time restrictions, your organisation or a parent may have blocked third-party keyboards."
        ),
        Topic(
            id: 2,
            question: "Is Full Access safe?",
            answer: "iOS shows the same warning for every keyboard that uses the internet. Neural Key only sends the text you choose to improve, translate or restyle. Everyday typing is not collected, and password fields always use the iOS keyboard."
        ),
        Topic(
            id: 3,
            question: "Neural Key doesn't show up when I type",
            answer: "Touch and hold the globe key at the bottom of the keyboard and choose **Neural Key**. Password fields, phone-number pads and some apps (for example banking apps) only allow the iOS keyboard."
        ),
        Topic(
            id: 4,
            question: "The app still says it isn't added",
            answer: "Come back to Neural Key after changing Settings so it can check again. If nothing changes, use **I've already added it** on the setup screen to carry on."
        ),
        Topic(
            id: 5,
            question: "AI features aren't working",
            answer: "They need both **Allow Full Access** and an internet connection. Open the keyboard once after turning Full Access on so it can confirm the change."
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NKSpacing.l) {
                    statusCard

                    VStack(spacing: NKSpacing.xs) {
                        ForEach(topics) { topic in
                            TopicRow(question: topic.question, answer: topic.answer)
                        }
                    }

                    VStack(spacing: NKSpacing.xxs) {
                        Button {
                            dismiss()
                            onOpenSettings()
                        } label: {
                            Label("Open Settings", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.nkPrimary)

                        if let mailURL = AppLinks.supportMailURL {
                            Button {
                                openURL(mailURL)
                            } label: {
                                Label("Contact Support", systemImage: "envelope")
                            }
                            .buttonStyle(.nkTextAccent)
                        }

                        Text(verbatim: AppLinks.supportEmail)
                            .nkFont(.caption)
                            .foregroundColor(NKColor.textTertiary)
                            .textSelection(.enabled)
                    }
                }
                .padding(NKSpacing.l)
            }
            .background(NKColor.background.ignoresSafeArea())
            .navigationTitle("Setup Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarBackground(NKColor.background, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: NKSpacing.s) {
            Text("CURRENT STATUS")
                .nkFont(.overline)
                .tracking(1.2)
                .foregroundColor(NKColor.textSecondary)

            statusLine(
                isOK: status.isKeyboardAdded,
                okText: "Keyboard added",
                pendingText: "Keyboard not added yet"
            )
            statusLine(
                isOK: status.fullAccess == .granted,
                okText: "Full Access on",
                pendingText: status.fullAccess == .denied ? "Full Access off" : "Full Access not confirmed yet"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nkCard()
    }

    private func statusLine(isOK: Bool, okText: LocalizedStringKey, pendingText: LocalizedStringKey) -> some View {
        HStack(spacing: NKSpacing.xs) {
            Image(systemName: isOK ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundColor(isOK ? NKColor.success : NKColor.textTertiary)
                .accessibilityHidden(true)
            Text(isOK ? okText : pendingText)
                .nkFont(.subheadline)
                .foregroundColor(isOK ? NKColor.textPrimary : NKColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Expandable question and answer.
private struct TopicRow: View {
    let question: LocalizedStringKey
    let answer: LocalizedStringKey

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: NKSpacing.s) {
                    Text(question)
                        .font(NKTypography.font(.subheadline).weight(.semibold))
                        .foregroundColor(NKColor.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(NKColor.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: NKSize.minTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(isExpanded ? "Collapses the answer" : "Expands the answer"))

            if isExpanded {
                Text(answer)
                    .nkFont(.footnote)
                    .foregroundColor(NKColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, NKSpacing.s)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, NKSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous)
                .fill(NKColor.surfaceRaised.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NKRadius.button, style: .continuous)
                .stroke(NKColor.borderSubtle, lineWidth: 1)
        )
    }
}
