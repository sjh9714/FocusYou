import SwiftUI
import SwiftData

// MARK: - 메인 대시보드 창 (v0.5 리디자인)

struct MainDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \BlockProfile.createdAt)
    private var profiles: [BlockProfile]
    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]

    @State private var showThemePicker = false

    var body: some View {
        Group {
            if settingsViewModel.hasCompletedOnboarding {
                dashboardContent
            } else {
                OnboardingView()
            }
        }
    }

    // MARK: - 대시보드 콘텐츠

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.Design.spacingXL) {
                header
                if appState.showError {
                    ErrorPanelView(bodyFont: .callout)
                }
                if appState.showPrivateRelayWarning {
                    PrivateRelayWarningPanel(bodyFont: .callout)
                }
                heroCard
                todayStatsRow
                quickActionsBar
                recentSessionsCard
            }
            .padding(Constants.Design.spacingXL)
        }
        .background(themeManager.background)
        .animation(.quickEase, value: appState.showPrivateRelayWarning)
        .onAppear {
            appState.ensureActiveProfile(in: profiles)
        }
        .onChange(of: profiles.count) { _, _ in
            appState.ensureActiveProfile(in: profiles)
        }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Constants.Design.spacingXS) {
                Text("Focus You Dashboard")
                    .font(.title2.bold())
                Text("집중 세션 관리 및 통계")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: Constants.Design.spacingSM) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
            .padding(.horizontal, Constants.Design.spacingMD)
            .padding(.vertical, Constants.Design.spacingSM)
            .background(statusColor.opacity(0.08), in: Capsule())
        }
    }

    // MARK: - 히어로 카드 (상태별)

    private var heroCard: some View {
        Group {
            switch appState.focusState {
            case .idle:
                DashboardIdleHeroView()
            case .focusing, .paused:
                DashboardActiveHeroView(statusTitle: statusTitle)
            case .completed:
                DashboardCompletedHeroView(currentStreakDays: currentStreakDays)
            }
        }
        .animation(.mediumEase, value: appState.focusState)
    }

    // MARK: - 오늘 통계

    private var todayStatsRow: some View {
        DashboardStatsRowView(
            focusedSeconds: todayFocusedSeconds,
            completedPomodoroCount: todayCompletedPomodoroCount,
            completionRate: todayCompletionRate,
            streakDays: currentStreakDays
        )
    }

    // MARK: - 퀵 액션 바

    private var quickActionsBar: some View {
        DashboardQuickActionsView(showThemePicker: $showThemePicker)
    }

    // MARK: - 최근 세션

    private var recentSessionsCard: some View {
        DashboardRecentSessionsView(todaySessions: todaySessions)
    }

    // MARK: - 데이터

    private var todaySessions: [FocusSession] {
        let start = Date().startOfDay
        return sessions.filter { $0.startedAt >= start }
    }

    private var todayFocusedSeconds: Int {
        todaySessions.reduce(0) { $0 + $1.actualDuration }
    }

    private var todayCompletedPomodoroCount: Int {
        todaySessions.filter { $0.timerMode == "pomodoro" && $0.wasCompleted }.count
    }

    private var todayCompletionRate: Int {
        guard !todaySessions.isEmpty else { return 0 }
        let completed = todaySessions.filter(\.wasCompleted).count
        return Int((Double(completed) / Double(todaySessions.count)) * 100)
    }

    private var currentStreakDays: Int {
        StreakCalculator.calculate(from: sessions).current
    }

    // MARK: - 상태 표시

    private var statusTitle: String {
        switch appState.focusState {
        case .idle: return String(localized: "대기 중")
        case .focusing:
            if appState.timerMode == .flowmodoro {
                let isBreak = appState.currentFlowmodoroPhase == .rest
                return isBreak ? String(localized: "플로우 휴식 중") : String(localized: "플로우 진행 중")
            }
            return appState.timerMode == .pomodoro ? String(localized: "뽀모도로 진행 중") : String(localized: "집중 진행 중")
        case .paused: return String(localized: "일시정지")
        case .completed: return String(localized: "세션 완료")
        }
    }

    private var statusColor: Color {
        switch appState.focusState {
        case .idle: return .secondary
        case .focusing: return themeManager.primary
        case .paused: return themeManager.pauseButton
        case .completed: return themeManager.completed
        }
    }
}

#Preview {
    MainDashboardView()
        .environment(AppState())
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .environment(LicenseManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
        .frame(width: 820, height: 620)
}
