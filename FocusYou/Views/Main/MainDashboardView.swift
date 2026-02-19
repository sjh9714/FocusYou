import SwiftUI
import SwiftData

// MARK: - 메인 대시보드 창 (v0.5 리디자인)

struct MainDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LicenseManager.self) private var licenseManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \BlockProfile.createdAt)
    private var profiles: [BlockProfile]
    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]

    @State private var quickStartMode: AppState.TimerMode = .free
    @State private var customFreeMinutes: Double = Double(Constants.Timer.presets.first ?? 25)
    @State private var selectedFreePreset: Int? = Constants.Timer.presets.first ?? 25
    @State private var pomodoroConfiguration: PomodoroConfiguration = .default
    @State private var cancelIntensity: Int = 0
    @State private var cancelLockoutMinutes: Int = 5
    @State private var blocklistMode: String = "blocklist"
    @State private var isSessionActionInFlight = false
    @State private var showDashStopConfirmation = false
    @State private var showThemePicker = false
    @State private var showDashIntentionInput = false
    @State private var dashIntentionText = ""
    @State private var dashRetrospectCompleted = false
    @State private var dashFocusQuote: QuoteEntry?
    @State private var showDashPaywall = false
    @Namespace private var dashModeNamespace

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
            loadProfileTimerSettings()
        }
        .onChange(of: profiles.count) { _, _ in
            appState.ensureActiveProfile(in: profiles)
        }
        .onChange(of: appState.activeProfileID) { _, _ in
            loadProfileTimerSettings()
        }
        .sheet(isPresented: $showDashPaywall) {
            PaywallView(reason: .timerLimit)
                .environment(themeManager)
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
            if let rejoinInfo = appState.pendingScheduleRejoin {
                dashScheduleRejoinBanner(rejoinInfo)
            }

            HStack(spacing: Constants.Design.spacingSM) {
                IconBadge(systemName: "bolt.fill", color: themeManager.primary, size: 36)
                Text("새 세션 시작")
                    .font(.headline)
            }

            activeProfilePicker

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
                SegmentedPill(
                    title: "플로우",
                    tag: AppState.TimerMode.flowmodoro,
                    selection: $quickStartMode,
                    namespace: dashModeNamespace,
                    activeColor: themeManager.primary
                )
            }
            .padding(Constants.Design.spacingXS)
            .background(Color.secondary.opacity(0.06), in: Capsule())

            switch quickStartMode {
            case .free:
                freeTimerConfig
            case .pomodoro:
                pomodoroTimerConfig
            case .flowmodoro:
                flowmodoroConfig
            }

            HStack(spacing: Constants.Design.spacingMD) {
                Label("\(activeSites.count)개 사이트", systemImage: "globe")
                Label("\(activeApps.count)개 앱", systemImage: "app.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)

            dashCancelIntensityPicker

            if showDashIntentionInput {
                dashIntentionInputSection
            } else {
                Button {
                    if settingsViewModel.showIntentionInput {
                        showDashIntentionInput = true
                    } else {
                        startSessionFromDashboard(intention: nil)
                    }
                } label: {
                    Label(startButtonTitle, systemImage: "bolt.fill")
                }
                .primaryActionStyle(color: themeManager.startButton)
                .disabled(isSessionActionInFlight || activeProfile == nil)
            }
        }
        .frostedCard()
        .animation(.mediumEase, value: showDashIntentionInput)
    }

    private var dashIntentionInputSection: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            HStack(spacing: Constants.Design.spacingSM) {
                Image(systemName: "target")
                    .foregroundStyle(themeManager.primary)
                Text("이번 세션의 의도")
                    .font(.callout.weight(.medium))
            }

            TextField("무엇에 집중할까요?", text: $dashIntentionText)
                .textFieldStyle(.plain)
                .font(.callout)
                .padding(Constants.Design.spacingMD)
                .background(
                    Color.secondary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                )
                .onSubmit {
                    let trimmed = dashIntentionText.trimmingCharacters(in: .whitespacesAndNewlines)
                    startSessionFromDashboard(intention: trimmed.isEmpty ? nil : trimmed)
                }

            Button {
                let trimmed = dashIntentionText.trimmingCharacters(in: .whitespacesAndNewlines)
                startSessionFromDashboard(intention: trimmed.isEmpty ? nil : trimmed)
            } label: {
                Label("집중 시작", systemImage: "bolt.fill")
            }
            .primaryActionStyle(color: themeManager.startButton)
            .disabled(isSessionActionInFlight)
        }
    }

    private var activeProfilePicker: some View {
        HStack(spacing: Constants.Design.spacingSM) {
            ForEach(profiles) { profile in
                let isActive = profile.persistentModelID == activeProfile?.persistentModelID

                Button {
                    appState.setActiveProfile(profile)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: profile.icon)
                            .font(.caption)
                        Text(profile.name)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, Constants.Design.spacingSM)
                    .padding(.vertical, 5)
                    .background(
                        Color(hex: profile.color).opacity(isActive ? 0.2 : 0.08),
                        in: Capsule()
                    )
                    .foregroundStyle(Color(hex: profile.color))
                    .overlay(
                        Capsule()
                            .stroke(
                                Color(hex: profile.color).opacity(isActive ? 0.55 : 0),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(profile.name) 프로필 선택")
            }

            Button {
                openWindow(id: "profiles")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, Constants.Design.spacingSM)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08), in: Capsule())
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("프로필 추가")
        }
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
                        title: String(localized: "\(minutes)분"),
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
                let dashSliderMax = licenseManager.isPro
                    ? Constants.Timer.maximumMinutes
                    : Constants.Subscription.freeTimerMaxMinutes

                Slider(
                    value: $customFreeMinutes,
                    in: Double(Constants.Timer.minimumMinutes)...Double(dashSliderMax)
                )
                .tint(themeManager.primary)
                .onChange(of: customFreeMinutes) { _, newValue in
                    customFreeMinutes = newValue.rounded()
                    let rounded = Int(customFreeMinutes)
                    if Constants.Timer.presets.contains(rounded) {
                        selectedFreePreset = rounded
                    } else {
                        selectedFreePreset = nil
                    }
                }

                HStack {
                    Text("\(Constants.Timer.minimumMinutes)분")
                    Spacer()
                    if !licenseManager.isPro {
                        Button {
                            showDashPaywall = true
                        } label: {
                            HStack(spacing: 2) {
                                Text("\(dashSliderMax)분")
                                ProBadge()
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("\(dashSliderMax)분")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
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

    // MARK: - 플로우모도로 설정

    private var flowmodoroConfig: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            Image(systemName: "infinity")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(themeManager.primary)

            VStack(spacing: Constants.Design.spacingSM) {
                Text("원하는 만큼 집중하세요")
                    .font(.callout.weight(.medium))
                Text("집중 시간의 1/5이 휴식으로 자동 부여됩니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 취소 강도

    private var dashCancelIntensityPicker: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingXS) {
            Text("취소 강도")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: Constants.Design.spacingSM) {
                dashIntensityChip("기본", level: 0, proRequired: false)
                dashIntensityChip("강함", level: 1, proRequired: true)
                dashIntensityChip("하드코어", level: 2, proRequired: true)
            }
        }
    }

    private func dashIntensityChip(_ title: String, level: Int, proRequired: Bool) -> some View {
        let isBlocked = proRequired && licenseManager.requiresPro(feature: .hardcoreMode)
        return HStack(spacing: 2) {
            ChipButton(
                title: title,
                isSelected: cancelIntensity == level,
                color: themeManager.primary
            ) {
                if isBlocked { return }
                withAnimation(.quickEase) {
                    cancelIntensity = level
                }
            }
            if isBlocked {
                ProBadge()
            }
        }
    }

    private var startButtonTitle: String {
        switch quickStartMode {
        case .free:
            return String(localized: "\(selectedDurationMinutes)분 집중 시작")
        case .pomodoro:
            return String(localized: "뽀모도로 시작")
        case .flowmodoro:
            return String(localized: "플로우 시작")
        }
    }

    // 진행 중 → 라이브 타이머
    @ViewBuilder
    private var activeHero: some View {
        if let scheduleName = appState.activeScheduleName {
            dashScheduleBanner(scheduleName)
        }

        HStack(spacing: Constants.Design.spacingXL) {
            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                Text(statusTitle)
                    .font(.headline)

                Text(statusDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let intention = appState.currentSession?.intention, !intention.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.caption2)
                        Text(intention)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(themeManager.primary)
                }

                if let startedAt = appState.currentSession?.startedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(startedAt.formatted(date: .omitted, time: .shortened)) 시작")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                if showDashStopConfirmation {
                    dashStopConfirmation
                } else {
                    HStack(spacing: Constants.Design.spacingSM) {
                        if isDashFlowmodoroFocus {
                            Button {
                                finishFlowmodoroFromDashboard()
                            } label: {
                                Label("집중 완료", systemImage: "checkmark.circle.fill")
                            }
                            .primaryActionStyle(color: themeManager.primary)
                            .disabled(isSessionActionInFlight)
                        } else {
                            Button {
                                if appState.focusState == .paused {
                                    appState.resumeSession()
                                } else {
                                    appState.pauseSession()
                                }
                            } label: {
                                Label(
                                    LocalizedStringKey(appState.focusState == .paused ? "재개" : "일시정지"),
                                    systemImage: appState.focusState == .paused ? "play.fill" : "pause.fill"
                                )
                            }
                            .secondaryActionStyle(color: themeManager.pauseButton)
                            .disabled(isSessionActionInFlight)
                        }

                        dashCancelButton
                    }

                    dashCancelLockoutBadge
                }
            }

            Spacer()

            VStack(spacing: Constants.Design.spacingXS) {
                Text(remainingTimerText)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(themeManager.primary)

                Text(isDashFlowmodoroFocus ? "경과 시간" : "남은 시간")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frostedCard()
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                .stroke(themeManager.primary.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            if settingsViewModel.showMotivationQuotes {
                dashFocusQuote = QuoteService.randomQuote()
            }
        }

        if settingsViewModel.showMotivationQuotes, let quote = dashFocusQuote {
            HStack(spacing: Constants.Design.spacingSM) {
                Image(systemName: "quote.opening")
                    .font(.caption2)
                    .foregroundStyle(themeManager.accent.opacity(0.6))

                Text(quote.text)
                    .font(.caption.italic())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text("— \(quote.author)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frostedCard()
            .onTapGesture {
                withAnimation(.quickEase) {
                    dashFocusQuote = QuoteService.randomQuote()
                }
            }
        }
    }

    // 완료 → 축하
    private var completedHero: some View {
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
                    dashRetrospectCompleted = false
                } label: {
                    Label("확인", systemImage: "checkmark")
                }
                .primaryActionStyle(color: themeManager.primary)
                .frame(width: 100)
            }

            if settingsViewModel.showRetrospect && !dashRetrospectCompleted {
                RetrospectView(
                    level: settingsViewModel.retrospectLevel,
                    onComplete: { data in
                        appState.saveRetrospectFull(
                            emoji: data.emoji,
                            text: data.text,
                            rating: data.rating
                        )
                        dashRetrospectCompleted = true
                    },
                    onSkip: {
                        dashRetrospectCompleted = true
                    }
                )
            }
        }
        .frostedCard()
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

    private var activeProfile: BlockProfile? {
        appState.activeProfile(from: profiles) ?? profiles.first
    }

    private var activeSites: [BlockedSite] {
        guard let activeProfile else { return [] }
        return activeProfile.blockedSites.filter(\.isEnabled)
    }

    private var activeApps: [BlockedApp] {
        guard let activeProfile else { return [] }
        return activeProfile.blockedApps.filter(\.isEnabled)
    }

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

    // MARK: - 프로필 동기화

    private func loadProfileTimerSettings() {
        guard let profile = activeProfile else { return }
        quickStartMode = AppState.TimerMode(rawValue: profile.timerMode) ?? .free
        let focusMinutes = profile.focusDuration / 60
        selectedFreePreset = Constants.Timer.presets.contains(focusMinutes) ? focusMinutes : nil
        customFreeMinutes = Double(focusMinutes)
        pomodoroConfiguration = PomodoroConfiguration(
            focusMinutes: focusMinutes,
            shortBreakMinutes: profile.breakDuration / 60,
            longBreakMinutes: profile.longBreakDuration / 60,
            cycles: profile.pomodoroCount
        )
        cancelIntensity = profile.cancelIntensity ?? 0
        cancelLockoutMinutes = profile.cancelLockoutMinutes ?? 5
        blocklistMode = profile.blocklistMode ?? "blocklist"
    }

    // MARK: - 세션 액션

    private func startSessionFromDashboard(intention: String? = nil) {
        guard !isSessionActionInFlight else { return }
        isSessionActionInFlight = true

        let selectedDuration: TimeInterval
        switch quickStartMode {
        case .free:
            selectedDuration = TimeInterval(selectedDurationMinutes * 60)
        case .pomodoro:
            selectedDuration = TimeInterval(pomodoroConfiguration.focusMinutes * 60)
        case .flowmodoro:
            selectedDuration = Constants.Timer.flowmodoroMaxDuration
        }

        Task { @MainActor in
            await appState.startFocusSession(
                duration: selectedDuration,
                sites: activeSites,
                apps: activeApps,
                modelContext: modelContext,
                mode: quickStartMode,
                pomodoroConfiguration: pomodoroConfiguration,
                intention: intention,
                blocklistMode: blocklistMode,
                cancelIntensity: cancelIntensity,
                cancelLockoutMinutes: cancelLockoutMinutes
            )
            isSessionActionInFlight = false
            showDashIntentionInput = false
            dashIntentionText = ""
        }
    }

    private func finishFlowmodoroFromDashboard() {
        guard !isSessionActionInFlight else { return }
        isSessionActionInFlight = true

        Task { @MainActor in
            await appState.finishFlowmodoroFocus(modelContext: modelContext)
            isSessionActionInFlight = false
        }
    }

    private func stopSessionFromDashboard() {
        guard !isSessionActionInFlight else { return }
        isSessionActionInFlight = true

        Task { @MainActor in
            await appState.stopSession(modelContext: modelContext)
            isSessionActionInFlight = false
            showDashStopConfirmation = false
        }
    }

    // MARK: - 취소 강도별 버튼 (대시보드)

    @ViewBuilder
    private var dashCancelButton: some View {
        switch appState.currentCancelIntensity {
        case 2:
            if appState.isEmergencyUnlockActive {
                dashEmergencyUnlockView
            } else {
                Button {
                    appState.requestEmergencyUnlock()
                } label: {
                    Label("비상 해제", systemImage: "exclamationmark.shield.fill")
                }
                .secondaryActionStyle(color: themeManager.stopButton)
                .disabled(appState.emergencyUnlockUsedToday || isSessionActionInFlight)
            }
        case 1:
            Button {
                showDashStopConfirmation = true
            } label: {
                Label("중지", systemImage: "stop.fill")
            }
            .secondaryActionStyle(color: themeManager.stopButton)
            .disabled(!appState.canCancel || isSessionActionInFlight)
        default:
            Button {
                showDashStopConfirmation = true
            } label: {
                Label("중지", systemImage: "stop.fill")
            }
            .secondaryActionStyle(color: themeManager.stopButton)
            .disabled(isSessionActionInFlight)
        }
    }

    private var dashStopConfirmation: some View {
        VStack(spacing: Constants.Design.spacingSM) {
            Text("집중을 중지하시겠습니까?")
                .font(.callout.weight(.medium))

            HStack(spacing: Constants.Design.spacingSM) {
                Button {
                    showDashStopConfirmation = false
                } label: {
                    Label("계속 집중", systemImage: "play.fill")
                }
                .secondaryActionStyle(color: themeManager.primary)

                Button {
                    stopSessionFromDashboard()
                } label: {
                    Label("중지", systemImage: "stop.fill")
                }
                .primaryActionStyle(color: themeManager.stopButton)
            }
        }
    }

    @ViewBuilder
    private var dashCancelLockoutBadge: some View {
        if appState.currentCancelIntensity == 1, !appState.canCancel {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("중지 잠금 \(Int(appState.cancelLockoutRemainingSeconds))초 남음")
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(themeManager.stopButton.opacity(0.7))
        } else if appState.currentCancelIntensity == 2, !appState.isEmergencyUnlockActive {
            HStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption2)
                Text(
                    LocalizedStringKey(
                        appState.emergencyUnlockUsedToday
                            ? "오늘 비상 해제를 이미 사용했습니다"
                            : "하드코어 모드 — 비상 해제만 가능"
                    )
                )
                .font(.caption)
            }
            .foregroundStyle(themeManager.stopButton.opacity(0.7))
        }
    }

    private var dashEmergencyUnlockView: some View {
        VStack(spacing: Constants.Design.spacingXS) {
            if appState.emergencyUnlockCountdown > 0 {
                Text("\(Int(appState.emergencyUnlockCountdown))초 대기 중...")
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(themeManager.stopButton)
            }

            HStack(spacing: Constants.Design.spacingSM) {
                Button {
                    appState.cancelEmergencyUnlock()
                } label: {
                    Label("취소", systemImage: "xmark")
                }
                .secondaryActionStyle(color: themeManager.primary)

                Button {
                    Task {
                        await appState.confirmEmergencyUnlock(modelContext: modelContext)
                    }
                } label: {
                    Label("해제 확인", systemImage: "lock.open.fill")
                }
                .primaryActionStyle(color: themeManager.stopButton)
                .disabled(appState.emergencyUnlockCountdown > 0)
            }
        }
    }

    // MARK: - 스케줄 배너

    private func dashScheduleBanner(_ name: String) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            Image(systemName: "calendar.badge.clock")
                .font(.callout)
                .foregroundStyle(themeManager.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("진행 중인 스케줄")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.primary)
            }

            Spacer()
        }
        .padding(Constants.Design.spacingMD)
        .background(themeManager.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerMD))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                .stroke(themeManager.primary.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - 스케줄 재참여 배너

    private func dashScheduleRejoinBanner(_ info: AppState.PendingScheduleInfo) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
                .foregroundStyle(themeManager.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(info.scheduleName)
                    .font(.callout.weight(.semibold))
                Text("\(info.endTimeFormatted)까지 진행 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await appState.rejoinPendingSchedule(modelContext: modelContext)
                }
            } label: {
                Label("참여하기", systemImage: "play.fill")
            }
            .primaryActionStyle(color: themeManager.accent)
            .frame(width: 120)
        }
        .padding(Constants.Design.spacingMD)
        .background(themeManager.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerMD))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                .stroke(themeManager.accent.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - 상태 텍스트

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

    private var statusDetailText: String {
        switch appState.focusState {
        case .idle: return String(localized: "새 집중 세션을 시작해보세요")
        case .focusing, .paused:
            if appState.timerMode == .pomodoro {
                return "\(appState.pomodoroPhaseTitle) · \(appState.pomodoroCycleProgressText)"
            }
            if appState.timerMode == .flowmodoro {
                let isBreak = appState.currentFlowmodoroPhase == .rest
                return isBreak ? String(localized: "휴식 카운트다운") : String(localized: "플로우모도로")
            }
            return String(localized: "자유 타이머")
        case .completed: return appState.completedSummaryText
        }
    }

    private var remainingTimerText: String {
        switch appState.focusState {
        case .focusing, .paused:
            if isDashFlowmodoroFocus {
                return "▲ \(appState.timer.elapsedTime.formattedAsTimer)"
            }
            return appState.timer.remainingTime.formattedAsTimer
        case .idle: return "00:00"
        case .completed: return "DONE"
        }
    }

    private var isDashFlowmodoroFocus: Bool {
        appState.timerMode == .flowmodoro && appState.currentFlowmodoroPhase == .focus
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
