import SwiftUI
import SwiftData

// MARK: - 메인 대시보드 창 (v0.5 리디자인)

struct MainDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query(filter: #Predicate<BlockedSite> { $0.isEnabled })
    private var enabledSites: [BlockedSite]
    @Query(filter: #Predicate<BlockedApp> { $0.isEnabled })
    private var enabledApps: [BlockedApp]
    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]

    @State private var quickStartMode: AppState.TimerMode = .free
    @State private var customFreeMinutes: Double = Double(Constants.Timer.presets.first ?? 25)
    @State private var selectedFreePreset: Int? = Constants.Timer.presets.first ?? 25
    @State private var pomodoroConfiguration: PomodoroConfiguration = .default
    @State private var isSessionActionInFlight = false
    @State private var showThemePicker = false
    @Namespace private var dashModeNamespace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.Design.spacingXL) {
                header
                if appState.showError {
                    dashboardErrorPanel
                }
                if appState.showPrivateRelayWarning {
                    dashboardPrivateRelayPanel
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
    }

    // MARK: - 에러 패널

    private var dashboardErrorPanel: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Label("오류", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(themeManager.stopButton)

            Text(appState.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: Constants.Design.spacingSM) {
                if appState.canRetryBlockingDeactivation {
                    Button {
                        Task {
                            await appState.retryBlockingDeactivation()
                        }
                    } label: {
                        Text("다시 시도")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionStyle(color: themeManager.stopButton)
                }

                Button {
                    appState.dismissError()
                } label: {
                    Text("닫기")
                        .frame(maxWidth: .infinity)
                }
                .secondaryActionStyle(color: .secondary)
            }
        }
        .frostedCard()
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                .stroke(themeManager.stopButton.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Private Relay 경고 패널

    private var dashboardPrivateRelayPanel: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Label(
                "Private Relay가 Safari 차단을 우회 중",
                systemImage: "exclamationmark.shield.fill"
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(.orange)

            Text("iCloud Private Relay가 켜져 있어 Safari에서 웹사이트 차단이 우회됩니다. 아래 방법 중 하나를 선택하세요.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                Label {
                    Text("Chrome, Firefox 등에서는 정상 차단됩니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                }

                Button {
                    appState.openPrivateRelaySettings()
                } label: {
                    Label("Private Relay 설정 열기", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .primaryActionStyle(color: .orange)
            }

            Button {
                appState.dismissPrivateRelayWarning()
            } label: {
                Text("닫기")
                    .frame(maxWidth: .infinity)
            }
            .secondaryActionStyle(color: .secondary)
        }
        .frostedCard()
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                .stroke(Color.orange.opacity(0.15), lineWidth: 0.5)
        )
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
                idleHero
            case .focusing, .paused:
                activeHero
            case .completed:
                completedHero
            }
        }
        .animation(.mediumEase, value: appState.focusState)
    }

    // 유휴 → 빠른 시작 CTA
    private var idleHero: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingLG) {
            HStack(spacing: Constants.Design.spacingSM) {
                IconBadge(systemName: "bolt.fill", color: themeManager.primary, size: 36)
                Text("새 세션 시작")
                    .font(.headline)
            }

            // 모드 피커
            HStack(spacing: 4) {
                SegmentedPill(
                    title: "자유",
                    tag: AppState.TimerMode.free,
                    selection: $quickStartMode,
                    namespace: dashModeNamespace,
                    activeColor: themeManager.primary
                )
                SegmentedPill(
                    title: "뽀모도로",
                    tag: AppState.TimerMode.pomodoro,
                    selection: $quickStartMode,
                    namespace: dashModeNamespace,
                    activeColor: themeManager.primary
                )
            }
            .padding(3)
            .background(Color.secondary.opacity(0.06), in: Capsule())

            if quickStartMode == .free {
                freeTimerConfig
            } else {
                pomodoroTimerConfig
            }

            HStack(spacing: Constants.Design.spacingMD) {
                Label("\(enabledSites.count)개 사이트", systemImage: "globe")
                Label("\(enabledApps.count)개 앱", systemImage: "app.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button {
                startSessionFromDashboard()
            } label: {
                Label(startButtonTitle, systemImage: "bolt.fill")
            }
            .primaryActionStyle(color: themeManager.startButton)
            .disabled(isSessionActionInFlight)
        }
        .frostedCard()
    }

    // MARK: - 자유 모드 설정

    private var selectedDurationMinutes: Int {
        selectedFreePreset ?? Int(customFreeMinutes)
    }

    private var freeTimerConfig: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            // 큰 시간 표시
            Text(TimeInterval(selectedDurationMinutes * 60).formattedAsTimer)
                .font(.system(size: 36, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(themeManager.primary)
                .contentTransition(.numericText())

            // 프리셋 칩
            HStack(spacing: Constants.Design.spacingSM) {
                ForEach(Constants.Timer.presets, id: \.self) { minutes in
                    ChipButton(
                        title: "\(minutes)분",
                        isSelected: selectedFreePreset == minutes,
                        color: themeManager.primary
                    ) {
                        selectedFreePreset = minutes
                        customFreeMinutes = Double(minutes)
                    }
                }
            }

            // 커스텀 슬라이더
            VStack(spacing: Constants.Design.spacingXS) {
                Slider(
                    value: $customFreeMinutes,
                    in: Double(Constants.Timer.minimumMinutes)...Double(Constants.Timer.maximumMinutes),
                    step: 1
                ) {
                    Text("시간 설정")
                } minimumValueLabel: {
                    Text("\(Constants.Timer.minimumMinutes)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } maximumValueLabel: {
                    Text("\(Constants.Timer.maximumMinutes)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .tint(themeManager.primary)
                .onChange(of: customFreeMinutes) { _, newValue in
                    let rounded = Int(newValue)
                    if Constants.Timer.presets.contains(rounded) {
                        selectedFreePreset = rounded
                    } else {
                        selectedFreePreset = nil
                    }
                }
            }
        }
        .animation(.quickEase, value: selectedDurationMinutes)
    }

    // MARK: - 뽀모도로 설정

    private var pomodoroTimerConfig: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            // 큰 시간 표시 (집중 시간)
            Text(TimeInterval(pomodoroConfiguration.focusMinutes * 60).formattedAsTimer)
                .font(.system(size: 36, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(themeManager.primary)
                .contentTransition(.numericText())

            PomodoroConfigView(configuration: $pomodoroConfiguration)
        }
        .animation(.quickEase, value: pomodoroConfiguration.focusMinutes)
    }

    private var startButtonTitle: String {
        quickStartMode == .pomodoro
            ? "뽀모도로 시작"
            : "\(selectedDurationMinutes)분 집중 시작"
    }

    // 진행 중 → 라이브 타이머
    private var activeHero: some View {
        HStack(spacing: Constants.Design.spacingXL) {
            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                Text(statusTitle)
                    .font(.headline)

                Text(statusDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: Constants.Design.spacingSM) {
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
                    }
                    .secondaryActionStyle(color: themeManager.pauseButton)
                    .disabled(isSessionActionInFlight)

                    Button {
                        stopSessionFromDashboard()
                    } label: {
                        Label("중지", systemImage: "stop.fill")
                    }
                    .secondaryActionStyle(color: themeManager.stopButton)
                    .disabled(isSessionActionInFlight)
                }
            }

            Spacer()

            VStack(spacing: Constants.Design.spacingXS) {
                Text(remainingTimerText)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(themeManager.primary)

                Text("남은 시간")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frostedCard()
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                .stroke(themeManager.primary.opacity(0.15), lineWidth: 0.5)
        )
    }

    // 완료 → 축하
    private var completedHero: some View {
        HStack(spacing: Constants.Design.spacingLG) {
            IconBadge(systemName: "checkmark.circle.fill", color: themeManager.completed, size: 44)

            VStack(alignment: .leading, spacing: Constants.Design.spacingXS) {
                Text("세션 완료!")
                    .font(.headline)
                Text(appState.completedSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                appState.resetToIdle()
            } label: {
                Label("확인", systemImage: "checkmark")
            }
            .primaryActionStyle(color: themeManager.primary)
            .frame(width: 100)
        }
        .frostedCard()
    }

    // MARK: - 오늘 통계

    private var todayStatsRow: some View {
        HStack(spacing: Constants.Design.spacingMD) {
            statCard(
                icon: "timer",
                color: themeManager.primary,
                value: TimeInterval(todayFocusedSeconds).formattedAsReadable,
                label: "오늘 집중 시간"
            )
            statCard(
                icon: "chart.bar.fill",
                color: themeManager.secondary,
                value: "\(todayCompletedPomodoroCount)회",
                label: "완료한 뽀모도로"
            )
            statCard(
                icon: "checkmark.seal.fill",
                color: themeManager.accent,
                value: "\(todayCompletionRate)%",
                label: "세션 완료율"
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

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedCard()
    }

    // MARK: - 퀵 액션 바

    private var quickActionsBar: some View {
        HStack(spacing: Constants.Design.spacingMD) {
            dashboardAction(title: "차단 목록", symbol: "list.bullet.rectangle", tint: themeManager.primary) {
                openWindow(id: "block-list")
            }
            dashboardAction(title: "설정", symbol: "gearshape", tint: themeManager.accent) {
                openWindow(id: "settings")
            }

            // 테마 퀵 피커
            Button {
                showThemePicker.toggle()
            } label: {
                HStack(spacing: Constants.Design.spacingSM) {
                    Text(themeManager.selectedTheme.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Circle().fill(themeManager.primary).frame(width: 10, height: 10)
                        Circle().fill(themeManager.secondary).frame(width: 10, height: 10)
                        Circle().fill(themeManager.accent).frame(width: 10, height: 10)
                    }

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
            .popover(isPresented: $showThemePicker) {
                themePickerPopover
            }
        }
    }

    private func dashboardAction(
        title: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .secondaryActionStyle(color: tint)
    }

    // MARK: - 테마 피커 팝오버

    private var themePickerPopover: some View {
        VStack(spacing: 0) {
            Text("테마 선택")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Constants.Design.spacingMD)
                .padding(.vertical, Constants.Design.spacingSM)

            Rectangle().fill(.quaternary).frame(height: 0.5)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(themeManager.availableThemes) { theme in
                        let isSelected = theme.id == themeManager.selectedThemeID

                        Button {
                            withAnimation(.quickEase) {
                                themeManager.selectTheme(id: theme.id)
                            }
                        } label: {
                            HStack(spacing: Constants.Design.spacingSM) {
                                HStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: theme.primaryHex))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: theme.secondaryHex))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: theme.accentHex))
                                }
                                .frame(width: 40, height: 12)
                                .clipShape(RoundedRectangle(cornerRadius: 3))

                                Text(theme.name)
                                    .font(.callout)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color(hex: theme.primaryHex))
                                }
                            }
                            .padding(.horizontal, Constants.Design.spacingMD)
                            .padding(.vertical, Constants.Design.spacingSM)
                            .background(
                                isSelected
                                    ? Color(hex: theme.primaryHex).opacity(0.06)
                                    : Color.clear
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 220, height: 340)
    }

    // MARK: - 최근 세션 (테이블)

    private var recentSessionsCard: some View {
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
            Text(session.timerMode == "pomodoro" ? "뽀모도로" : "자유")
                .font(.callout.weight(.medium))

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

    // MARK: - 세션 액션

    private func startSessionFromDashboard() {
        guard !isSessionActionInFlight else { return }
        isSessionActionInFlight = true

        let selectedDuration = quickStartMode == .free
            ? TimeInterval(selectedDurationMinutes * 60)
            : TimeInterval(pomodoroConfiguration.focusMinutes * 60)

        Task { @MainActor in
            await appState.startFocusSession(
                duration: selectedDuration,
                sites: enabledSites,
                apps: enabledApps,
                modelContext: modelContext,
                mode: quickStartMode,
                pomodoroConfiguration: pomodoroConfiguration
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

    // MARK: - 상태 텍스트

    private var statusTitle: String {
        switch appState.focusState {
        case .idle: return "대기 중"
        case .focusing: return appState.timerMode == .pomodoro ? "뽀모도로 진행 중" : "집중 진행 중"
        case .paused: return "일시정지"
        case .completed: return "세션 완료"
        }
    }

    private var statusDetailText: String {
        switch appState.focusState {
        case .idle: return "새 집중 세션을 시작해보세요"
        case .focusing, .paused:
            if appState.timerMode == .pomodoro {
                return "\(appState.pomodoroPhaseTitle) · \(appState.pomodoroCycleProgressText)"
            }
            return "자유 타이머"
        case .completed: return appState.completedSummaryText
        }
    }

    private var remainingTimerText: String {
        switch appState.focusState {
        case .focusing, .paused:
            return appState.timer.remainingTime.formattedAsTimer
        case .idle: return "00:00"
        case .completed: return "DONE"
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
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
        .frame(width: 820, height: 620)
}
