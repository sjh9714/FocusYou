import SwiftUI
import SwiftData

// MARK: - 메인 대시보드 창
// 팝오버는 빠른 조작, 메인 창은 비교/탐색 중심 작업에 사용

struct MainDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \BlockedSite.createdAt, order: .reverse)
    private var blockedSites: [BlockedSite]
    @Query(sort: \BlockedApp.createdAt, order: .reverse)
    private var blockedApps: [BlockedApp]
    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]
    @State private var quickStartMode: AppState.TimerMode = .free
    @State private var selectedFreeMinutes: Int = Constants.Timer.presets.first ?? 25
    @State private var isSessionActionInFlight = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                sessionStatusCard
                sessionControlCard
                todayStatsRow
                themePreviewCard
                quickActionsCard
                recentSessionsCard
            }
            .padding(20)
        }
        .background(themeManager.background)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus You Dashboard")
                    .font(.title2.bold())
                Text("팝오버는 빠른 실행, 이 창은 관리/비교 용도로 사용")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
        }
    }

    private var sessionStatusCard: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("현재 세션")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(statusTitle)
                        .font(.headline)
                    Text(statusDetailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(remainingTimerText)
                    .font(.system(size: 32, weight: .light, design: .monospaced))
                    .foregroundStyle(themeManager.textPrimary)
            }
        }
        .groupBoxStyle(.automatic)
    }

    private var sessionControlCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("빠른 세션 제어")
                    .font(.headline)

                switch appState.focusState {
                case .idle:
                    idleSessionControls
                case .focusing, .paused:
                    activeSessionControls
                case .completed:
                    completedSessionControls
                }
            }
        }
    }

    private var idleSessionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                quickModeButton(.free, title: "자유")
                quickModeButton(.pomodoro, title: "뽀모도로")
            }

            if quickStartMode == .free {
                HStack(spacing: 8) {
                    ForEach(Constants.Timer.presets, id: \.self) { minutes in
                        Button {
                            selectedFreeMinutes = minutes
                        } label: {
                            Text("\(minutes)분")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    selectedFreeMinutes == minutes
                                        ? themeManager.primary.opacity(0.2)
                                        : Color.secondary.opacity(0.1)
                                )
                                .foregroundStyle(
                                    selectedFreeMinutes == minutes
                                        ? themeManager.primary
                                        : themeManager.textPrimary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("기본 설정으로 시작: 집중 \(Constants.Timer.pomodoroFocusDefaultMinutes)분 · \(Constants.Timer.pomodoroCyclesDefault)사이클")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Label("\(enabledSiteCount)개 사이트", systemImage: "globe")
                Label("\(enabledAppCount)개 앱", systemImage: "app.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button {
                startSessionFromDashboard()
            } label: {
                Label(
                    quickStartMode == .pomodoro
                        ? "뽀모도로 시작"
                        : "\(selectedFreeMinutes)분 집중 시작",
                    systemImage: "play.fill"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(themeManager.startButton)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isSessionActionInFlight)
        }
    }

    private var activeSessionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(
                appState.timerMode == .pomodoro
                    ? "\(appState.pomodoroPhaseTitle) · \(appState.pomodoroCycleProgressText)"
                    : "자유 타이머 진행 중"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    if appState.focusState == .paused {
                        appState.resumeSession()
                    } else {
                        appState.pauseSession()
                    }
                } label: {
                    Label(
                        appState.focusState == .paused ? "재개" : "일시정지",
                        systemImage: appState.focusState == .paused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(themeManager.pauseButton.opacity(0.15))
                    .foregroundStyle(themeManager.pauseButton)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(isSessionActionInFlight)

                Button {
                    stopSessionFromDashboard()
                } label: {
                    Label("중지", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(themeManager.stopButton.opacity(0.15))
                        .foregroundStyle(themeManager.stopButton)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(isSessionActionInFlight)
            }
        }
    }

    private var completedSessionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.completedSummaryText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                appState.resetToIdle()
            } label: {
                Label("완료 확인", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(themeManager.primary.opacity(0.16))
                    .foregroundStyle(themeManager.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    private func quickModeButton(_ mode: AppState.TimerMode, title: String) -> some View {
        Button {
            quickStartMode = mode
        } label: {
            Text(title)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    quickStartMode == mode
                        ? themeManager.primary.opacity(0.2)
                        : Color.secondary.opacity(0.12)
                )
                .foregroundStyle(
                    quickStartMode == mode ? themeManager.primary : themeManager.textPrimary
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func startSessionFromDashboard() {
        guard !isSessionActionInFlight else { return }
        isSessionActionInFlight = true

        let selectedDuration = quickStartMode == .free
            ? TimeInterval(selectedFreeMinutes * 60)
            : TimeInterval(Constants.Timer.pomodoroFocusDefaultMinutes * 60)

        Task { @MainActor in
            await appState.startFocusSession(
                duration: selectedDuration,
                sites: blockedSites,
                apps: blockedApps,
                modelContext: modelContext,
                mode: quickStartMode,
                pomodoroConfiguration: .default
            )
            isSessionActionInFlight = false
        }
    }

    private func stopSessionFromDashboard() {
        guard !isSessionActionInFlight else { return }
        isSessionActionInFlight = true

        Task { @MainActor in
            await appState.stopSession(modelContext: modelContext)
            isSessionActionInFlight = false
        }
    }

    private var todayStatsRow: some View {
        HStack(spacing: 12) {
            statCard(
                title: "오늘 집중 시간",
                value: TimeInterval(todayFocusedSeconds).formattedAsReadable,
                symbol: "timer",
                accent: themeManager.primary
            )
            statCard(
                title: "완료한 뽀모도로",
                value: "🍅 ×\(todayCompletedPomodoroCount)",
                symbol: "chart.bar.fill",
                accent: themeManager.secondary
            )
            statCard(
                title: "세션 완료율",
                value: "\(todayCompletionRate)%",
                symbol: "checkmark.seal.fill",
                accent: themeManager.accent
            )
        }
    }

    private func statCard(
        title: String,
        value: String,
        symbol: String,
        accent: Color
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var themePreviewCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("테마 실시간 미리보기")
                    .font(.headline)

                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeManager.primary.opacity(0.2))
                        .frame(width: 90, height: 60)
                        .overlay(
                            Text("25:00")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(themeManager.primary)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("현재 테마: \(themeManager.selectedTheme.name)")
                            .font(.callout)
                        HStack(spacing: 6) {
                            Circle().fill(themeManager.primary)
                            Circle().fill(themeManager.secondary)
                            Circle().fill(themeManager.accent)
                            Circle().fill(themeManager.stopButton)
                        }
                        .frame(height: 10)
                    }
                    Spacer()
                }
            }
        }
    }

    private var quickActionsCard: some View {
        GroupBox {
            HStack(spacing: 12) {
                dashboardActionButton(
                    title: "차단 목록",
                    symbol: "list.bullet.rectangle",
                    tint: themeManager.primary
                ) {
                    openWindow(id: "block-list")
                }

                dashboardActionButton(
                    title: "설정",
                    symbol: "gearshape",
                    tint: themeManager.accent
                ) {
                    openWindow(id: "settings")
                }
            }
        }
    }

    private func dashboardActionButton(
        title: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(tint.opacity(0.14))
                .foregroundStyle(tint)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var recentSessionsCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("오늘 세션")
                    .font(.headline)

                if todaySessions.isEmpty {
                    Text("아직 기록된 세션이 없습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(todaySessions.prefix(5)) { session in
                        HStack {
                            Text(session.timerMode == "pomodoro" ? "🍅 뽀모도로" : "⏱ 자유")
                                .font(.callout)
                            Spacer()
                            Text(TimeInterval(session.actualDuration).formattedAsReadable)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(session.wasCompleted ? "완료" : "중지")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    session.wasCompleted
                                        ? themeManager.secondary.opacity(0.2)
                                        : themeManager.stopButton.opacity(0.16)
                                )
                                .foregroundStyle(
                                    session.wasCompleted ? themeManager.secondary : themeManager.stopButton
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var todaySessions: [FocusSession] {
        let start = Date().startOfDay
        return sessions.filter { $0.startedAt >= start }
    }

    private var todayFocusedSeconds: Int {
        todaySessions.reduce(0) { partial, session in
            partial + session.actualDuration
        }
    }

    private var todayCompletedPomodoroCount: Int {
        todaySessions.filter { $0.timerMode == "pomodoro" && $0.wasCompleted }.count
    }

    private var todayCompletionRate: Int {
        guard !todaySessions.isEmpty else { return 0 }
        let completed = todaySessions.filter(\.wasCompleted).count
        return Int((Double(completed) / Double(todaySessions.count)) * 100)
    }

    private var enabledSiteCount: Int {
        blockedSites.filter(\.isEnabled).count
    }

    private var enabledAppCount: Int {
        blockedApps.filter(\.isEnabled).count
    }

    private var statusTitle: String {
        switch appState.focusState {
        case .idle:
            return "대기 중"
        case .focusing:
            return appState.timerMode == .pomodoro ? "뽀모도로 진행 중" : "집중 진행 중"
        case .paused:
            return "일시정지"
        case .completed:
            return "세션 완료"
        }
    }

    private var statusDetailText: String {
        switch appState.focusState {
        case .idle:
            return "새 집중 세션을 시작해보세요"
        case .focusing, .paused:
            if appState.timerMode == .pomodoro {
                return "\(appState.pomodoroPhaseTitle) · \(appState.pomodoroCycleProgressText)"
            }
            return "자유 타이머"
        case .completed:
            return appState.completedSummaryText
        }
    }

    private var remainingTimerText: String {
        switch appState.focusState {
        case .focusing, .paused:
            return appState.timer.remainingTime.formattedAsTimer
        case .idle:
            return "00:00"
        case .completed:
            return "DONE"
        }
    }

    private var statusColor: Color {
        switch appState.focusState {
        case .idle:
            return .secondary
        case .focusing:
            return themeManager.primary
        case .paused:
            return themeManager.pauseButton
        case .completed:
            return themeManager.completed
        }
    }
}

#Preview {
    MainDashboardView()
        .environment(AppState())
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
        .frame(width: 820, height: 620)
}
