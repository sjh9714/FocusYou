import SwiftUI
import SwiftData
import Charts

// MARK: - 통계 뷰 (v0.5)

struct StatsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]
    @State private var viewModel = StatsViewModel()
    @Namespace private var periodNamespace

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(.quaternary).frame(height: 0.5)

            ScrollView {
                VStack(spacing: Constants.Design.spacingXL) {
                    periodPicker
                    summaryCards
                    dailyChart
                    modeRatioChart
                    sessionHistory
                }
                .padding()
            }
        }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack {
            Text("집중 통계")
                .font(.title3.bold())
            Spacer()
        }
        .padding()
    }

    // MARK: - 기간 피커

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(StatsViewModel.Period.allCases, id: \.self) { period in
                SegmentedPill(
                    title: period.rawValue,
                    tag: period,
                    selection: Binding(
                        get: { viewModel.selectedPeriod },
                        set: { viewModel.selectedPeriod = $0 }
                    ),
                    namespace: periodNamespace,
                    activeColor: themeManager.primary
                )
            }
        }
        .padding(3)
        .background(Color.secondary.opacity(0.06), in: Capsule())
    }

    // MARK: - 요약 카드

    private var summaryCards: some View {
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
            summaryItem(
                icon: "checkmark.seal.fill",
                color: themeManager.accent,
                value: "\(viewModel.completionRate(from: sessions))%",
                label: "완료율"
            )
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

    // MARK: - 일별 차트

    private var dailyChart: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Text("일별 집중 시간")
                .font(.headline)

            let data = viewModel.dailyData(from: sessions)
            if data.isEmpty {
                chartEmptyState
            } else {
                Chart(data) { entry in
                    BarMark(
                        x: .value("날짜", entry.dayLabel),
                        y: .value("분", entry.focusMinutes)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.primary.opacity(0.7), themeManager.primary],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(Constants.Design.cornerSM)
                }
                .chartYAxisLabel("분")
                .frame(height: 180)
            }
        }
        .frostedCard()
    }

    // MARK: - 모드 비율 차트

    private var modeRatioChart: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Text("모드 비율")
                .font(.headline)

            let pomodoroPercent = viewModel.pomodoroRatio(from: sessions)
            let freePercent = 100 - pomodoroPercent

            if viewModel.sessionCount(from: sessions) == 0 {
                chartEmptyState
            } else {
                HStack(spacing: Constants.Design.spacingXL) {
                    Chart {
                        SectorMark(
                            angle: .value("뽀모도로", pomodoroPercent),
                            innerRadius: .ratio(0.55)
                        )
                        .foregroundStyle(themeManager.primary)

                        SectorMark(
                            angle: .value("자유", freePercent),
                            innerRadius: .ratio(0.55)
                        )
                        .foregroundStyle(themeManager.secondary)
                    }
                    .frame(width: 120, height: 120)

                    VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
                        modeLabel(color: themeManager.primary, text: "뽀모도로", percent: pomodoroPercent)
                        modeLabel(color: themeManager.secondary, text: "자유", percent: freePercent)
                    }

                    Spacer()
                }
            }
        }
        .frostedCard()
    }

    private func modeLabel(color: Color, text: String, percent: Int) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text)
                .font(.callout)
            Spacer()
            Text("\(percent)%")
                .font(.callout.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private var chartEmptyState: some View {
        HStack {
            Spacer()
            Text("데이터가 없습니다")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.vertical, Constants.Design.spacingXL)
            Spacer()
        }
    }

    // MARK: - 세션 히스토리

    private var sessionHistory: some View {
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
            Text(session.timerMode == "pomodoro" ? "뽀모도로" : "자유")
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
    StatsView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
        .frame(width: 600, height: 700)
}
