import SwiftUI
import SwiftData

// MARK: - 완료 콘텐츠 (v0.5 리디자인)

struct CompletedContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Query(
        filter: #Predicate<FocusSession> { $0.wasCompleted },
        sort: \FocusSession.startedAt,
        order: .reverse
    )
    private var sessions: [FocusSession]
    @State private var checkScale: CGFloat = 0
    @State private var showSummary = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var retrospectCompleted = false

    private var streakInfo: StreakCalculator.StreakInfo {
        StreakCalculator.calculate(from: sessions)
    }

    var body: some View {
        ZStack {
            VStack(spacing: Constants.Design.spacingXL) {
                celebrationIcon
                summaryContent
                completionQuote
                retrospectSection
                confirmButton
            }

            // 마일스톤 축하 오버레이 (v1.5)
            if let milestone = appState.pendingMilestone {
                MilestoneCelebrationView(
                    milestone: milestone,
                    onDismiss: { appState.pendingMilestone = nil }
                )
            }

            // 레벨업 축하 오버레이 (v1.x)
            if appState.pendingMilestone == nil, let newLevel = appState.pendingLevelUp {
                LevelUpCelebrationView(
                    newLevel: newLevel,
                    onDismiss: { appState.pendingLevelUp = nil }
                )
            }
        }
        .padding(.vertical, Constants.Design.spacingSM)
        .onAppear {
            playCelebration()
            appState.lastCompletedStreakInfo = streakInfo
        }
    }

    // MARK: - 완료 명언 (v1.x)

    @ViewBuilder
    private var completionQuote: some View {
        if settingsViewModel.showMotivationQuotes && showSummary {
            QuoteView()
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - 회고 섹션

    @ViewBuilder
    private var retrospectSection: some View {
        if settingsViewModel.showRetrospect && showSummary && !retrospectCompleted {
            RetrospectView(
                level: settingsViewModel.retrospectLevel,
                onComplete: { data in
                    appState.saveRetrospectFull(
                        emoji: data.emoji,
                        text: data.text,
                        rating: data.rating
                    )
                    retrospectCompleted = true
                },
                onSkip: {
                    retrospectCompleted = true
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - 축하 아이콘

    private var celebrationIcon: some View {
        ZStack {
            // 컨페티 파티클
            ForEach(confettiParticles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(particle.offset)
                    .opacity(particle.opacity)
            }

            // 외곽 글로우 링
            Circle()
                .fill(themeManager.completed.opacity(0.08))
                .frame(width: 80, height: 80)
                .scaleEffect(checkScale)

            // 체크마크
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(themeManager.completed)
                .scaleEffect(checkScale)
        }
        .frame(height: 90)
    }

    // MARK: - 요약 콘텐츠

    @ViewBuilder
    private var summaryContent: some View {
        if showSummary {
            VStack(spacing: Constants.Design.spacingMD) {
                Text("집중 완료!")
                    .font(.title3.bold())

                VStack(spacing: Constants.Design.spacingSM) {
                    if let intention = appState.lastCompletedIntention, !intention.isEmpty {
                        summaryRow(
                            icon: "target",
                            color: themeManager.accent,
                            text: intention
                        )
                    }

                    summaryRow(
                        icon: "clock.fill",
                        color: themeManager.primary,
                        text: appState.completedSummaryText
                    )

                    if let detailText = appState.completedDetailText {
                        summaryRow(
                            icon: "chart.bar.fill",
                            color: themeManager.secondary,
                            text: detailText
                        )
                    }

                    if streakInfo.current > 0 {
                        summaryRow(
                            icon: "flame.fill",
                            color: themeManager.warning,
                            text: String(localized: "\(streakInfo.current)일 연속 집중!")
                        )
                    }

                    if appState.lastCompletedXPEarned > 0 {
                        summaryRow(
                            icon: "star.fill",
                            color: themeManager.accent,
                            text: "+\(appState.lastCompletedXPEarned) XP"
                        )
                    }
                }
                .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func summaryRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            IconBadge(systemName: icon, color: color, size: 28)
            Text(LocalizedStringKey(text))
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - 확인 버튼

    @ViewBuilder
    private var confirmButton: some View {
        if showSummary {
            Button {
                withAnimation(.focusSpring) {
                    appState.resetToIdle()
                }
            } label: {
                Label("확인", systemImage: "checkmark")
            }
            .primaryActionStyle(color: themeManager.primary)
            .transition(.opacity)
        }
    }

    // MARK: - 축하 애니메이션

    private func playCelebration() {
        // 체크마크 스케일인
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
            checkScale = 1.0
        }

        // 컨페티 버스트
        spawnConfetti()

        // 요약 페이드인
        withAnimation(.mediumEase.delay(0.5)) {
            showSummary = true
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
            let distance: CGFloat = CGFloat.random(in: 30...50)
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

#Preview("완료") {
    CompletedContentView()
        .environment(AppState())
        .environment(ThemeManager.shared)
        .environment(SettingsViewModel())
        .frame(width: 340)
        .padding()
}
