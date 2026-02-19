import SwiftUI

// MARK: - 오늘 세션 목록 카드

struct DashboardRecentSessionsView: View {
    @Environment(ThemeManager.self) private var themeManager

    let todaySessions: [FocusSession]

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Text("오늘 세션")
                .font(.headline)

            if todaySessions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: Constants.Design.spacingSM) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("아직 기록된 세션이 없습니다.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Constants.Design.spacingXL)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(todaySessions.prefix(8).enumerated()), id: \.element.id) { index, session in
                        sessionRow(session, isEven: index.isMultiple(of: 2))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerMD))
            }
        }
        .frostedCard()
    }

    private func sessionRow(_ session: FocusSession, isEven: Bool) -> some View {
        HStack(spacing: Constants.Design.spacingMD) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(session.timerMode == "pomodoro" ? "뽀모도로" : session.timerMode == "flowmodoro" ? "플로우" : "자유"))
                    .font(.callout.weight(.medium))

                if let intention = session.intention, !intention.isEmpty {
                    Text(intention)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let emoji = session.retrospectEmoji {
                Text(emoji)
                    .font(.caption)
            }

            Text(TimeInterval(session.actualDuration).formattedAsReadable)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(LocalizedStringKey(session.wasCompleted ? "완료" : "중지"))
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    session.wasCompleted
                        ? themeManager.secondary.opacity(0.12)
                        : themeManager.stopButton.opacity(0.1)
                )
                .foregroundStyle(
                    session.wasCompleted ? themeManager.secondary : themeManager.stopButton
                )
                .clipShape(Capsule())
        }
        .padding(.horizontal, Constants.Design.spacingMD)
        .padding(.vertical, Constants.Design.spacingSM)
        .background(isEven ? Color.secondary.opacity(0.03) : Color.clear)
    }
}

#Preview {
    DashboardRecentSessionsView(todaySessions: [])
        .environment(ThemeManager.shared)
        .padding()
}
