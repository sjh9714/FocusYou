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
                    StatsSummaryCardsView(sessions: sessions, viewModel: viewModel)
                    StatsChartsView(sessions: sessions, viewModel: viewModel)
                    monthlyTrendSection
                    heatmapSection
                    intentionSection
                    BadgeGalleryView()
                    QuoteView()
                    StatsSessionHistoryView(sessions: sessions, viewModel: viewModel)
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

    // MARK: - 성장 (v1.5)

    private var growthSection: some View {
        GrowthView(
            totalHours: viewModel.totalFocusHours(from: sessions),
            xpInfo: LevelManager.xpInfo(from: sessions)
        )
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
