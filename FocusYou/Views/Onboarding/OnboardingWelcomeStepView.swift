import SwiftUI

// MARK: - 온보딩 Step 1: 환영 (v1.0)

struct OnboardingWelcomeStepView: View {
    @Environment(ThemeManager.self) private var themeManager

    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var shieldScale: CGFloat = 0
    @State private var showContent = false

    var body: some View {
        VStack(spacing: Constants.Design.spacingXXL) {
            Spacer()

            heroIcon
            welcomeText
            valuePropositions

            Spacer()

            actionButtons
        }
        .padding(.horizontal, Constants.Design.spacingXXL * 2)
        .padding(.bottom, Constants.Design.spacingXXL)
        .onAppear { playEntrance() }
        .onDisappear {
            shieldScale = 0
            showContent = false
        }
    }

    // MARK: - 히어로 아이콘

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(themeManager.primary.opacity(0.08))
                .frame(width: 120, height: 120)
                .scaleEffect(shieldScale)

            Image(systemName: "shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(themeManager.primaryGradient)
                .scaleEffect(shieldScale)
        }
        .accessibilityLabel("Focus You")
    }

    // MARK: - 환영 텍스트

    @ViewBuilder
    private var welcomeText: some View {
        if showContent {
            VStack(spacing: Constants.Design.spacingMD) {
                Text("Focus You에 오신 걸\n환영합니다")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("25분 타이머로 바로 시작하고\n필요할 때 차단을 켜세요")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - 가치 제안

    @ViewBuilder
    private var valuePropositions: some View {
        if showContent {
            VStack(spacing: Constants.Design.spacingLG) {
                propositionRow(
                    icon: "timer",
                    color: themeManager.primary,
                    title: "타이머만 사용 가능",
                    subtitle: "차단 대상을 고르지 않아도 세션을 시작할 수 있어요"
                )
                propositionRow(
                    icon: "checkmark.shield.fill",
                    color: themeManager.secondary,
                    title: "차단은 승인 후 활성화",
                    subtitle: Constants.Distribution.isAppStoreBuild
                        ? "첫 차단 세션 전에 macOS에서 Network Extension 승인이 필요해요"
                        : "선택한 사이트와 앱이 있을 때만 차단이 활성화돼요"
                )
                propositionRow(
                    icon: "chart.bar.fill",
                    color: themeManager.accent,
                    title: "집중 습관 추적",
                    subtitle: "일일 통계와 연속 집중 기록"
                )
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func propositionRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: Constants.Design.spacingLG) {
            IconBadge(systemName: icon, color: color, size: 40)

            VStack(alignment: .leading, spacing: Constants.Design.spacingXS) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    // MARK: - 액션 버튼

    private var actionButtons: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            Button(action: onNext) {
                Text("시작하기")
            }
            .primaryActionStyle(color: themeManager.primary)

            Button(action: onSkip) {
                Text("건너뛰기")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 입장 애니메이션

    private func playEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
            shieldScale = 1.0
        }
        withAnimation(.mediumEase.delay(0.4)) {
            showContent = true
        }
    }
}

#Preview {
    OnboardingWelcomeStepView(onNext: {}, onSkip: {})
        .environment(ThemeManager.shared)
        .frame(width: 840, height: 620)
}
