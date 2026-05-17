import SwiftUI

// MARK: - 온보딩 Step 3: 준비 완료 (v1.0)

struct OnboardingReadyStepView: View {
    @Environment(ThemeManager.self) private var themeManager

    let onComplete: () -> Void

    @State private var checkScale: CGFloat = 0
    @State private var showContent = false
    @State private var confettiParticles: [ConfettiParticle] = []

    var body: some View {
        VStack(spacing: Constants.Design.spacingXXL) {
            Spacer()

            celebrationIcon
            readyText
            tipCards

            Spacer()

            completeButton
        }
        .padding(.horizontal, Constants.Design.spacingXXL * 2)
        .padding(.bottom, Constants.Design.spacingXXL)
        .onAppear { playCelebration() }
        .onDisappear {
            checkScale = 0
            showContent = false
            confettiParticles = []
        }
    }

    // MARK: - 축하 아이콘

    private var celebrationIcon: some View {
        ZStack {
            ForEach(confettiParticles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(particle.offset)
                    .opacity(particle.opacity)
            }

            Circle()
                .fill(themeManager.completed.opacity(0.08))
                .frame(width: 120, height: 120)
                .scaleEffect(checkScale)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(themeManager.completed)
                .scaleEffect(checkScale)
        }
        .frame(height: 140)
        .accessibilityLabel("준비 완료")
    }

    // MARK: - 준비 완료 텍스트

    @ViewBuilder
    private var readyText: some View {
        if showContent {
            VStack(spacing: Constants.Design.spacingMD) {
                Text("준비 완료!")
                    .font(.title.bold())

                Text("대시보드에서 25분 집중을 바로 시작할 수 있어요")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - 팁 카드

    @ViewBuilder
    private var tipCards: some View {
        if showContent {
            VStack(spacing: Constants.Design.spacingMD) {
                tipRow(
                    icon: "menubar.rectangle",
                    text: "메뉴바 아이콘을 클릭하면 빠르게 타이머를 시작할 수 있어요"
                )
                tipRow(
                    icon: "timer",
                    text: "차단 대상이 없으면 세션은 타이머만 실행됩니다"
                )
                tipRow(
                    icon: "checkmark.shield.fill",
                    text: Constants.Distribution.isAppStoreBuild
                        ? "차단을 쓰려면 첫 세션 전에 macOS Network Extension 승인이 필요해요"
                        : "차단 목록은 언제든 설정에서 수정할 수 있어요"
                )
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: Constants.Design.spacingMD) {
            IconBadge(systemName: icon, color: themeManager.accent, size: 36)

            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
        .accessibilityLabel(text)
    }

    // MARK: - 완료 버튼

    @ViewBuilder
    private var completeButton: some View {
        if showContent {
            Button(action: onComplete) {
                Label("시작하기", systemImage: "bolt.fill")
            }
            .primaryActionStyle(color: themeManager.startButton)
            .transition(.opacity)
        }
    }

    // MARK: - 축하 애니메이션

    private func playCelebration() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.1)) {
            checkScale = 1.0
        }

        spawnConfetti()

        withAnimation(.mediumEase.delay(0.5)) {
            showContent = true
        }
    }

    private func spawnConfetti() {
        let colors: [Color] = [
            themeManager.primary,
            themeManager.secondary,
            themeManager.accent,
            themeManager.completed,
        ]

        for i in 0..<12 {
            let angle = Double(i) * (360.0 / 12.0) * .pi / 180
            let distance = CGFloat.random(in: 35...55)
            let particle = ConfettiParticle(
                color: colors[i % colors.count],
                size: CGFloat.random(in: 4...7),
                offset: .zero,
                opacity: 0
            )
            confettiParticles.append(particle)

            let idx = confettiParticles.count - 1

            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                confettiParticles[idx].offset = CGSize(
                    width: cos(angle) * distance,
                    height: sin(angle) * distance
                )
                confettiParticles[idx].opacity = 1
            }

            withAnimation(.easeIn(duration: 0.3).delay(0.6)) {
                confettiParticles[idx].opacity = 0
            }
        }
    }
}

// MARK: - 컨페티 파티클

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var offset: CGSize
    var opacity: Double
}

#Preview {
    OnboardingReadyStepView(onComplete: {})
        .environment(ThemeManager.shared)
        .frame(width: 840, height: 620)
}
