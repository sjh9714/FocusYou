import SwiftUI

// MARK: - 통계 요약 카드

struct StatsSummaryCardsView: View {
    @Environment(ThemeManager.self) private var themeManager

    let sessions: [FocusSession]
    let viewModel: StatsViewModel

    var body: some View {
        let streak = viewModel.streakInfo(from: sessions)
        let balanceScore = BurnoutDetector.shared.calculateBalanceScore(
            sessions: sessions.map {
                FocusSessionData(startedAt: $0.startedAt, actualDuration: $0.actualDuration, sessionType: $0.sessionType)
            }
        )

        VStack(spacing: Constants.Design.spacingMD) {
            HStack(spacing: Constants.Design.spacingMD) {
                summaryItem(
                    icon: "timer",
                    color: themeManager.primary,
                    value: TimeInterval(viewModel.totalFocusSeconds(from: sessions)).formattedAsReadable,
                    label: "총 집중"
                )
                summaryItem(
                    icon: "number",
                    color: themeManager.secondary,
                    value: "\(viewModel.sessionCount(from: sessions))회",
                    label: "총 세션"
                )
            }
            HStack(spacing: Constants.Design.spacingMD) {
                summaryItem(
                    icon: "checkmark.seal.fill",
                    color: themeManager.accent,
                    value: "\(viewModel.completionRate(from: sessions))%",
                    label: "완료율"
                )
                summaryItem(
                    icon: "flame.fill",
                    color: themeManager.warning,
                    value: "\(streak.current)일",
                    label: "현재 스트릭"
                )
            }
            HStack(spacing: Constants.Design.spacingMD) {
                summaryItem(
                    icon: "heart.fill",
                    color: balanceScore >= 70 ? themeManager.success : balanceScore >= 40 ? themeManager.warning : themeManager.danger,
                    value: "\(balanceScore)점",
                    label: "균형 점수"
                )
            }
        }
    }

    private func summaryItem(
        icon: String,
        color: Color,
        value: String,
        label: String
    ) -> some View {
        VStack(spacing: Constants.Design.spacingSM) {
            IconBadge(systemName: icon, color: color, size: 32)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frostedCard()
    }
}

#Preview {
    StatsSummaryCardsView(sessions: [], viewModel: StatsViewModel())
        .environment(ThemeManager.shared)
        .padding()
}
