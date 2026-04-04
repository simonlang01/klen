import SwiftUI

// MARK: – Step model

private struct OnboardingStep {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var body: String? = nil
    var isAccentPicker = false
}

// MARK: – Main view

struct OnboardingView: View {
    let onFinish: () -> Void

    @EnvironmentObject private var appState: AppState
    @Environment(\.appAccent) private var accent
    @State private var currentStep = 0
    @State private var animateIn = false

    private var steps: [OnboardingStep] {[
        .init(
            icon: "checkmark.circle.fill",
            iconColor: .teal,
            title: NSLocalizedString("onboarding.welcome.title", comment: ""),
            subtitle: NSLocalizedString("onboarding.welcome.subtitle", comment: ""),
            body: NSLocalizedString("onboarding.welcome.body", comment: "")
        ),
        .init(
            icon: "plus.circle.fill",
            iconColor: .blue,
            title: NSLocalizedString("onboarding.quickadd.title", comment: ""),
            subtitle: NSLocalizedString("onboarding.quickadd.subtitle", comment: ""),
            body: NSLocalizedString("onboarding.quickadd.body", comment: "")
        ),
        .init(
            icon: "sparkles",
            iconColor: .purple,
            title: NSLocalizedString("onboarding.smart.title", comment: ""),
            subtitle: NSLocalizedString("onboarding.smart.subtitle", comment: ""),
            body: NSLocalizedString("onboarding.smart.body", comment: "")
        ),
        .init(
            icon: "folder.fill",
            iconColor: .orange,
            title: NSLocalizedString("onboarding.groups.title", comment: ""),
            subtitle: NSLocalizedString("onboarding.groups.subtitle", comment: ""),
            body: NSLocalizedString("onboarding.groups.body", comment: "")
        ),
        .init(
            icon: "arrow.2.circlepath",
            iconColor: .teal,
            title: NSLocalizedString("onboarding.recurring.title", comment: ""),
            subtitle: NSLocalizedString("onboarding.recurring.subtitle", comment: ""),
            body: NSLocalizedString("onboarding.recurring.body", comment: "")
        ),
        .init(
            icon: "paintpalette.fill",
            iconColor: .pink,
            title: NSLocalizedString("onboarding.accent.title", comment: ""),
            subtitle: NSLocalizedString("onboarding.accent.subtitle", comment: ""),
            isAccentPicker: true
        )
    ]}

    var body: some View {
        ZStack {
            // Background
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Step content
                stepContent(for: steps[currentStep])
                    .id(currentStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                Spacer()

                // Progress dots + navigation
                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentStep ? accent : Color.primary.opacity(0.15))
                                .frame(width: i == currentStep ? 20 : 8, height: 8)
                                .animation(.spring(duration: 0.3), value: currentStep)
                        }
                    }

                    Button {
                        advance()
                    } label: {
                        Text(LocalizedStringKey(currentStep == steps.count - 1 ? "onboarding.button.getStarted" : "onboarding.button.continue"))
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 200)
                            .padding(.vertical, 11)
                            .background(accent, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])

                    if currentStep < steps.count - 1 {
                        Button(LocalizedStringKey("onboarding.button.skip")) { finish() }
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 20)
                    }
                }
                .padding(.bottom, 36)
            }
        }
        .frame(width: 520, height: 480)
        .preferredColorScheme(appState.appearanceMode.colorScheme)
        .environment(\.appAccent, appState.accentOption.color)
    }

    // MARK: Step content

    @ViewBuilder
    private func stepContent(for step: OnboardingStep) -> some View {
        VStack(spacing: 0) {
            // Icon
            ZStack {
                Circle()
                    .fill(step.iconColor.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: step.icon)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(step.iconColor)
            }
            .padding(.bottom, 28)

            // Title + subtitle
            Text(step.title)
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Text(step.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)

            // Body or accent picker
            if step.isAccentPicker {
                accentPickerRow
            } else if let body = step.body {
                Text(body)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 360)
            }
        }
        .padding(.horizontal, 52)
    }

    // MARK: Accent picker

    private var accentPickerRow: some View {
        HStack(spacing: 14) {
            ForEach(AccentColorOption.allCases) { option in
                Button {
                    appState.accentOption = option
                } label: {
                    ZStack {
                        Circle()
                            .fill(option.color)
                            .frame(width: 34, height: 34)
                        if appState.accentOption == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay(
                        Circle()
                            .strokeBorder(appState.accentOption == option ? option.color : Color.clear, lineWidth: 2)
                            .scaleEffect(1.35)
                    )
                    .padding(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    // MARK: Navigation

    private func advance() {
        if currentStep < steps.count - 1 {
            withAnimation(.spring(duration: 0.35)) { currentStep += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        let flag = PersistenceController.dataDirectory.appendingPathComponent(".onboarding_complete")
        FileManager.default.createFile(atPath: flag.path, contents: nil)
        onFinish()
    }
}
