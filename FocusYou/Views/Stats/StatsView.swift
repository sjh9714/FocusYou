import SwiftUI
import SwiftData
import Charts

// MARK: - 통계 뷰 (v0.5, v1.5 확장)

struct StatsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LicenseManager.self) private var licenseManager
    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]
    @State private var viewModel = StatsViewModel()
    @State private var showExportSheet = false
    @State private var showPaywall = false
    @State private var paywallReason: PaywallReason = .statsLimit
    @Namespace private var periodNamespace

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(.quaternary).frame(height: 0.5)

            ScrollView {
                VStack(spacing: Constants.Design.spacingXL) {
                    periodPicker
                    growthSection
                    summaryCards
                    dailyChart
                    monthlyTrendSection
                    modeRatioChart
                    heatmapSection
                    intentionSection
                    BadgeGalleryView()
                    QuoteView()
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
            HStack(spacing: Constants.Design.spacingXS) {
                if !licenseManager.isPro {
                    ProBadge()
                }
                Button {
                    if licenseManager.requiresPro(feature: .dataExport) {
                        paywallReason = .proFeature(.dataExport)
                        showPaywall = true
                    } else {
                        showExportSheet = true
                    }
                } label: {
                    Label("내보내기", systemImage: "square.and.arrow.up")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(themeManager.primary)
            }
        }
        .padding()
        .sheet(isPresented: $showExportSheet) {
            ExportView(sessions: sessions)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: paywallReason)
                .environment(themeManager)
        }
    }

    // MARK: - 기간 피커

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(StatsViewModel.Period.allCases, id: \.self) { period in
                SegmentedPill(
                    title: period.displayName,
                    tag: period,
                    selection: Binding(
                        get: { viewModel.selectedPeriod },
                        set: { newPeriod in
                            if licenseManager.canUseStatsPeriod(newPeriod.rawValue) {
                                viewModel.selectedPeriod = newPeriod
                            } else {
                                paywallReason = .statsLimit
                                showPaywall = true
                            }
                        }
                    ),
                    namespace: periodNamespace,
                    activeColor: themeManager.primary
                )
            }
        }
        .padding(Constants.Design.spacingXS)
        .background(Color.secondary.opacity(0.06), in: Capsule())
    }

    // MARK: - 요약 카드

    private var summaryCards: some View {
        let streak = viewModel.streakInfo(from: sessions)
        let balanceScore = BurnoutDetector.shared.calculateBalanceScore(
            sessions: sessions.map {
                FocusSessionData(startedAt: $0.startedAt, actualDuration: $0.actualDuration, sessionType: $0.sessionType)
            }
        )
        return VStack(spacing: Constants.Design.spacingMD) {
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

    // MARK: - 월간 트렌드 (v1.5)

    @ViewBuilder
    private var monthlyTrendSection: some View {
        let data = viewModel.monthlyTrendData(from: sessions)
        if data.count >= 2 {
            if licenseManager.isPro {
                MonthlyTrendView(data: data)
            } else {
                RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                    .fill(Color.secondary.opacity(0.04))
                    .frame(height: 180)
                    .overlay { ProLockedOverlay(message: "월간 트렌드는 Pro에서 확인") }
                    .onTapGesture {
                        paywallReason = .proFeature(.advancedStats)
                        showPaywall = true
                    }
            }
        }
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

    // MARK: - 성장 (v1.5)

    private var growthSection: some View {
        GrowthView(
            totalHours: viewModel.totalFocusHours(from: sessions),
            xpInfo: LevelManager.xpInfo(from: sessions)
        )
    }

    // MARK: - 히트맵 (v1.5)

    @ViewBuilder
    private var heatmapSection: some View {
        if viewModel.selectedPeriod == .month || viewModel.selectedPeriod == .year {
            if licenseManager.isPro {
                HeatmapView(data: viewModel.heatmapData(from: sessions))
            } else {
                RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                    .fill(Color.secondary.opacity(0.04))
                    .frame(height: 180)
                    .overlay { ProLockedOverlay(message: "히트맵은 Pro에서 확인") }
                    .onTapGesture {
                        paywallReason = .proFeature(.advancedStats)
                        showPaywall = true
                    }
            }
        }
    }

    // MARK: - 의도별 분석 (v1.5)

    @ViewBuilder
    private var intentionSection: some View {
        let entries = viewModel.intentionBreakdown(from: sessions)
        if !entries.isEmpty {
            IntentionAnalysisView(entries: entries)
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
    StatsView()
        .environment(ThemeManager.shared)
        .environment(LicenseManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
            Badge.self,
        ], inMemory: true)
        .frame(width: 600, height: 700)
}
