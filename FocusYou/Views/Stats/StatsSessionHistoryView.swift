import SwiftUI

// MARK: - 세션 히스토리

struct StatsSessionHistoryView: View {
    @Environment(ThemeManager.self) private var themeManager

    let sessions: [FocusSession]
    let viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Text("세션 기록")
                .font(.headline)

            let filtered = viewModel.filteredSessions(from: sessions)
            if filtered.isEmpty {
                HStack {
                    Spacer()
                    Text("기록된 세션이 없습니다")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, Constants.Design.spacingLG)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filtered.prefix(10).enumerated()), id: \.element.id) { index, session in
                        historyRow(session, isEven: index.isMultiple(of: 2))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerMD))
            }
        }
        .frostedCard()
    }

    private func historyRow(_ session: FocusSession, isEven: Bool) -> some View {
        HStack(spacing: Constants.Design.spacingMD) {
            Text(session.timerMode == "pomodoro" ? "뽀모도로" : session.timerMode == "flowmodoro" ? "플로우" : "자유")
                .font(.callout.weight(.medium))

            Spacer()

            if let startDate = session.startedAt as Date? {
                Text(startDate, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Text(TimeInterval(session.actualDuration).formattedAsReadable)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(session.wasCompleted ? "완료" : "중지")
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
    StatsSessionHistoryView(sessions: [], viewModel: StatsViewModel())
        .environment(ThemeManager.shared)
        .padding()
}
