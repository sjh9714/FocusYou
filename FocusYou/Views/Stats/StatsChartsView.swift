import SwiftUI
import Charts

// MARK: - 통계 차트 (일별 + 모드 비율)

struct StatsChartsView: View {
    @Environment(ThemeManager.self) private var themeManager

    let sessions: [FocusSession]
    let viewModel: StatsViewModel

    var body: some View {
        VStack(spacing: Constants.Design.spacingXL) {
            dailyChart
            modeRatioChart
        }
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

    // MARK: - 모드 비율 차트 (v1.5: 3-way)

    private var modeRatioChart: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Text("모드 비율")
                .font(.headline)

            let ratios = viewModel.modeRatios(from: sessions)

            if ratios.isEmpty {
                chartEmptyState
            } else {
                HStack(spacing: Constants.Design.spacingXL) {
                    Chart(ratios) { entry in
                        SectorMark(
                            angle: .value(entry.mode, entry.count),
                            innerRadius: .ratio(0.55)
                        )
                        .foregroundStyle(modeColor(entry.modeID))
                    }
                    .frame(width: 120, height: 120)

                    VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
                        ForEach(ratios) { entry in
                            modeLabel(color: modeColor(entry.modeID), text: entry.mode, percent: entry.percent)
                        }
                    }

                    Spacer()
                }
            }
        }
        .frostedCard()
    }

    private func modeColor(_ modeID: String) -> Color {
        switch modeID {
        case "pomodoro": return themeManager.primary
        case "flowmodoro": return themeManager.accent
        default: return themeManager.secondary
        }
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
}

#Preview {
    StatsChartsView(sessions: [], viewModel: StatsViewModel())
        .environment(ThemeManager.shared)
        .padding()
}
