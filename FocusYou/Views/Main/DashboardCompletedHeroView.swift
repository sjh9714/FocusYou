import SwiftUI

// MARK: - 대시보드 완료 히어로 카드

struct DashboardCompletedHeroView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SettingsViewModel.self) private var settingsViewModel

    @State private var retrospectCompleted = false
    let currentStreakDays: Int

    var body: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            HStack(spacing: Constants.Design.spacingLG) {
                IconBadge(systemName: "checkmark.circle.fill", color: themeManager.completed, size: 44)

                VStack(alignment: .leading, spacing: Constants.Design.spacingXS) {
                    HStack(spacing: Constants.Design.spacingSM) {
                        Text("세션 완료!")
                            .font(.headline)
                        if let emoji = appState.completedSession?.retrospectEmoji {
                            Text(emoji)
                        }
                        if currentStreakDays > 0 {
                            Text("\(currentStreakDays)일 연속")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(themeManager.warning)
                        }
                    }
                    if let intention = appState.lastCompletedIntention, !intention.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption2)
                            Text(intention)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(themeManager.accent)
                    }
                    Text(appState.completedSummaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    appState.resetToIdle()
                    retrospectCompleted = false
                } label: {
                    Label("확인", systemImage: "checkmark")
                }
                .primaryActionStyle(color: themeManager.primary)
                .frame(width: 100)
            }

            if settingsViewModel.showRetrospect && !retrospectCompleted {
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
            }
        }
        .frostedCard()
    }
}

#Preview {
    DashboardCompletedHeroView(currentStreakDays: 3)
        .environment(AppState())
        .environment(ThemeManager.shared)
        .environment(SettingsViewModel())
        .padding()
}
