import SwiftUI

// MARK: - 오늘 통계 요약 행

struct DashboardStatsRowView: View {
    @Environment(ThemeManager.self) private var themeManager

    let focusedSeconds: Int
    let completedPomodoroCount: Int
    let completionRate: Int
    let streakDays: Int

    var body: some View {
        HStack(spacing: Constants.Design.spacingMD) {
            statCard(
                icon: "timer",
                color: themeManager.primary,
                value: TimeInterval(focusedSeconds).formattedAsReadable,
                label: "오늘 집중 시간"
            )
            statCard(
                icon: "chart.bar.fill",
                color: themeManager.secondary,
                value: String(localized: "\(completedPomodoroCount)회"),
                label: "완료한 뽀모도로"
            )
            statCard(
                icon: "checkmark.seal.fill",
                color: themeManager.accent,
                value: "\(completionRate)%",
                label: "세션 완료율"
            )
            statCard(
                icon: "flame.fill",
                color: themeManager.warning,
                value: String(localized: "\(streakDays)일"),
                label: "연속 집중"
            )
        }
    }

    private func statCard(
        icon: String,
        color: Color,
        value: String,
        label: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            IconBadge(systemName: icon, color: color, size: 32)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)

            Text(LocalizedStringKey(label))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedCard()
    }
}

#Preview {
    DashboardStatsRowView(
        focusedSeconds: 3600,
        completedPomodoroCount: 4,
        completionRate: 85,
        streakDays: 3
    )
    .environment(ThemeManager.shared)
    .padding()
}
