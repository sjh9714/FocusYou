import SwiftUI
import SwiftData

// MARK: - 온보딩 컨테이너 (v1.0)

struct OnboardingView: View {
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(ThemeManager.self) private var themeManager

    @State private var currentStep = 0
    @State private var direction: TransitionDirection = .forward

    private let totalSteps = 3

    private enum TransitionDirection {
        case forward, backward
    }

    var body: some View {
        VStack(spacing: 0) {
            progressIndicator
                .padding(.top, Constants.Design.spacingXL)
                .padding(.horizontal, Constants.Design.spacingXXL * 2)

            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(themeManager.background)
    }

    // MARK: - 프로그레스 인디케이터

    private var progressIndicator: some View {
        HStack(spacing: Constants.Design.spacingSM) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(
                        index <= currentStep
                            ? themeManager.primary
                            : Color.secondary.opacity(0.15)
                    )
                    .frame(height: 4)
                    .animation(.focusSpring, value: currentStep)
            }
        }
    }

    // MARK: - 스텝 콘텐츠

    private var stepContent: some View {
        Group {
            switch currentStep {
            case 0:
                OnboardingWelcomeStepView(
                    onNext: advanceStep,
                    onSkip: completeOnboarding
                )
            case 1:
                OnboardingBlockStepView(
                    onNext: advanceStep,
                    onBack: goBack,
                    onSkip: completeOnboarding
                )
            case 2:
                OnboardingReadyStepView(
                    onComplete: completeOnboarding
                )
            default:
                EmptyView()
            }
        }
        .transition(stepTransition)
        .animation(.mediumEase, value: currentStep)
    }

    // MARK: - 네비게이션

    private func advanceStep() {
        guard currentStep < totalSteps - 1 else { return }
        direction = .forward
        withAnimation(.mediumEase) {
            currentStep += 1
        }
    }

    private func goBack() {
        guard currentStep > 0 else { return }
        direction = .backward
        withAnimation(.mediumEase) {
            currentStep -= 1
        }
    }

    private func completeOnboarding() {
        withAnimation(.mediumEase) {
            settingsViewModel.hasCompletedOnboarding = true
        }
    }

    private var stepTransition: AnyTransition {
        switch direction {
        case .forward:
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
}

#Preview {
    OnboardingView()
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
        .frame(width: 840, height: 620)
}
