import SwiftUI
import SwiftData

// MARK: - 유휴 상태 콘텐츠 (v0.5 리디자인)

struct IdleContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(LicenseManager.self) private var licenseManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimerViewModel()
    @State private var showIntentionInput = false
    @State private var intentionText = ""
    @State private var showPaywall = false
    @State private var burnoutDetector = BurnoutDetector.shared
    @Namespace private var modeNamespace

    @Query(sort: \BlockProfile.createdAt)
    private var profiles: [BlockProfile]

    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var allSessions: [FocusSession]

    /// 최근 의도 (완료 세션에서 중복 제거, 최대 5개)
    private var recentIntentions: [String] {
        var seen = Set<String>()
        var result = [String]()
        for session in allSessions where session.wasCompleted {
            guard let intention = session.intention,
                  !intention.isEmpty,
                  !seen.contains(intention) else { continue }
            seen.insert(intention)
            result.append(intention)
            if result.count >= 5 { break }
        }
        return result
    }

    var body: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            // 번아웃 배너 (v1.5)
            if burnoutDetector.showBanner {
                BurnoutBannerView(
                    message: burnoutDetector.bannerMessage,
                    onDismiss: { burnoutDetector.dismissBanner() }
                )
            }

            if showIntentionInput {
                IntentionInputView(
                    intentionText: $intentionText,
                    recentIntentions: recentIntentions,
                    onStart: { intention in
                        startSessionWithIntention(intention)
                    }
                )
            } else {
                profileSelector
                modePicker
                timerDisplay
                timerOptions
                blockSummary
                startButton
                profileQuickStart
            }
        }
        .animation(.mediumEase, value: showIntentionInput)
        .onAppear {
            appState.ensureActiveProfile(in: profiles)
            updateBurnoutBanner()
        }
        .onChange(of: profiles.count) { _, _ in
            appState.ensureActiveProfile(in: profiles)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .timerLimit)
                .environment(themeManager)
        }
    }

    private func updateBurnoutBanner() {
        let todayStart = Date().startOfDay
        let todaySeconds = allSessions
            .filter { $0.startedAt >= todayStart && $0.sessionType == "focus" }
            .reduce(0) { $0 + $1.actualDuration }
        burnoutDetector.updateBanner(
            todayFocusSeconds: todaySeconds,
            dailyLimitHours: settingsViewModel.burnoutDailyLimitHours
        )
    }

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

    // MARK: - 프로필 선택

    @ViewBuilder
    private var profileSelector: some View {
        if !profiles.isEmpty {
            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                Text("현재 프로필")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                HStack(spacing: Constants.Design.spacingSM) {
                    ProfileSelectorView(
                        profiles: profiles,
                        activeProfile: activeProfile,
                        onSelect: { appState.setActiveProfile($0) }
                    )
                }
            }
        }
    }

    // MARK: - 모드 피커 (슬라이딩 캡슐)

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(TimerViewModel.TimerMode.allCases, id: \.self) { mode in
                SegmentedPill(
                    title: mode.displayName,
                    tag: mode,
                    selection: Binding(
                        get: { viewModel.selectedMode },
                        set: { viewModel.selectMode($0) }
                    ),
                    namespace: modeNamespace,
                    activeColor: themeManager.primary
                )
            }
        }
        .padding(Constants.Design.spacingXS)
        .background(Color.secondary.opacity(0.08), in: Capsule())
    }

    // MARK: - 시간 표시

    @ViewBuilder
    private var timerDisplay: some View {
        if viewModel.selectedMode == .flowmodoro {
            Image(systemName: "infinity")
                .font(.system(size: 42, weight: .ultraLight))
                .foregroundStyle(themeManager.textPrimary)
                .accessibilityLabel("플로우모도로 — 시간 제한 없음")
        } else {
            Text(viewModel.initialDurationSeconds.formattedAsTimer)
                .font(.system(size: 42, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(themeManager.textPrimary)
                .contentTransition(.numericText())
                .animation(.mediumEase, value: viewModel.initialDurationSeconds)
                .accessibilityLabel(
                    viewModel.selectedMode == .free
                        ? "\(viewModel.selectedDurationMinutes)분 타이머"
                        : "뽀모도로 집중 \(viewModel.pomodoroConfiguration.focusMinutes)분"
                )
        }
    }

    @ViewBuilder
    private var timerOptions: some View {
        switch viewModel.selectedMode {
        case .free:
            VStack(spacing: Constants.Design.spacingMD) {
                presetChips
                customSlider
            }
        case .pomodoro:
            VStack(spacing: Constants.Design.spacingSM) {
                Text(viewModel.pomodoroSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PomodoroConfigView(
                    configuration: Binding(
                        get: { viewModel.pomodoroConfiguration },
                        set: { viewModel.pomodoroConfiguration = $0 }
                    )
                )
            }
        case .flowmodoro:
            VStack(spacing: Constants.Design.spacingSM) {
                Text("원하는 만큼 집중하세요")
                    .font(.callout.weight(.medium))
                Text("집중 시간의 1/5이 휴식으로 자동 부여됩니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
        }
    }

    // MARK: - 프리셋 칩 버튼

    private var presetChips: some View {
        HStack(spacing: Constants.Design.spacingSM) {
            ForEach(Constants.Timer.presets, id: \.self) { minutes in
                ChipButton(
                    title: String(localized: "\(minutes)분"),
                    isSelected: viewModel.selectedPreset == minutes,
                    color: themeManager.primary
                ) {
                    withAnimation(.focusSpring) {
                        viewModel.selectPreset(minutes)
                    }
                }
                .accessibilityLabel("\(minutes)분 프리셋")
            }
        }
    }

    // MARK: - 커스텀 슬라이더

    private var sliderMaxMinutes: Int {
        licenseManager.isPro
            ? Constants.Timer.maximumMinutes
            : Constants.Subscription.freeTimerMaxMinutes
    }

    private var customSlider: some View {
        VStack(spacing: Constants.Design.spacingXS) {
            Slider(
                value: Binding(
                    get: { viewModel.customMinutes },
                    set: { viewModel.updateCustomMinutes($0) }
                ),
                in: Double(Constants.Timer.minimumMinutes)...Double(sliderMaxMinutes)
            )
            .tint(themeManager.primary)
            .accessibilityLabel("타이머 시간 설정")

            HStack {
                Text("\(Constants.Timer.minimumMinutes)분")
                Spacer()
                if !licenseManager.isPro {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 2) {
                            Text("\(sliderMaxMinutes)분")
                            ProBadge()
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("\(sliderMaxMinutes)분")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
    }

    // MARK: - 차단 요약

    @ViewBuilder
    private var blockSummary: some View {
        if !activeSites.isEmpty || !activeApps.isEmpty {
            HStack(spacing: Constants.Design.spacingMD) {
                if !activeSites.isEmpty {
                    Label(String(localized: "\(activeSites.count)개 사이트"), systemImage: "globe")
                }
                if !activeApps.isEmpty {
                    Label(String(localized: "\(activeApps.count)개 앱"), systemImage: "app.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 시작 버튼

    private var startButton: some View {
        Button {
            if settingsViewModel.showIntentionInput {
                showIntentionInput = true
            } else {
                startSessionWithIntention(nil)
            }
        } label: {
            Label(
                LocalizedStringKey(viewModel.selectedMode == .flowmodoro ? "플로우 시작" : "집중 시작"),
                systemImage: "bolt.fill"
            )
        }
        .primaryActionStyle(color: themeManager.startButton)
        .disabled(activeProfile == nil)
        .accessibilityLabel("집중 시작")
        .accessibilityHint("타이머를 시작하고 사이트와 앱 차단을 활성화합니다")
    }

    private func startSessionWithIntention(_ intention: String?) {
        Task {
            await appState.startFocusSession(
                duration: viewModel.initialDurationSeconds,
                sites: activeSites,
                apps: activeApps,
                modelContext: modelContext,
                mode: viewModel.selectedMode.appStateMode,
                pomodoroConfiguration: viewModel.pomodoroConfiguration,
                intention: intention
            )
        }
        showIntentionInput = false
        intentionText = ""
    }

    // MARK: - 프로필 빠른 시작

    @ViewBuilder
    private var profileQuickStart: some View {
        if !profiles.isEmpty {
            VStack(spacing: Constants.Design.spacingSM) {
                Text("빠른 시작")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Constants.Design.spacingSM) {
                    ForEach(profiles) { profile in
                        profileChip(profile)
                    }
                }
            }
        }
    }

    private func profileChip(_ profile: BlockProfile) -> some View {
        Button {
            Task {
                await appState.startSessionFromProfile(
                    profile,
                    modelContext: modelContext
                )
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: profile.icon)
                    .font(.caption2)
                Text(profile.name)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, Constants.Design.spacingSM)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                Color(hex: profile.color).opacity(0.1),
                in: Capsule()
            )
            .foregroundStyle(Color(hex: profile.color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(profile.name) 프로필로 집중 시작")
    }
}

// MARK: - 집중 중 콘텐츠 (v0.5 리디자인)

struct FocusingContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimerViewModel()
    @State private var phaseBadgeScale: CGFloat = 1.0
    @State private var breatheOpacity: Double = 1.0
    @State private var focusQuote: QuoteEntry?

    var body: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            if viewModel.showCancelConfirmation {
                stopConfirmation
            } else {
                countdownDisplay
                capsuleProgressBar
                statusBadge
                motivationQuote
                intentionBadge
                startTimeBadge
                controlButtons
            }
        }
        .animation(.mediumEase, value: viewModel.showCancelConfirmation)
        .onAppear {
            if settingsViewModel.showMotivationQuotes {
                focusQuote = QuoteService.randomQuote()
            }
        }
        .onChange(of: appState.currentPomodoroPhase?.type) { _, newValue in
            guard appState.timerMode == .pomodoro, newValue != nil else { return }
            animatePhaseBadge()
        }
        .onChange(of: appState.focusState) { _, newValue in
            if newValue == .paused {
                startBreatheAnimation()
            } else {
                breatheOpacity = 1.0
            }
        }
    }

    // MARK: - 중지 확인 (인라인)

    private var stopConfirmation: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(themeManager.stopButton)
                .symbolEffect(.pulse, options: .repeating)

            Text("집중을 중지하시겠습니까?")
                .font(.headline)

            Text("차단이 해제되고 세션이 기록됩니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: Constants.Design.spacingMD) {
                Button {
                    viewModel.showCancelConfirmation = false
                } label: {
                    Label("계속 집중", systemImage: "play.fill")
                }
                .secondaryActionStyle(color: themeManager.primary)

                Button {
                    Task {
                        await appState.stopSession(modelContext: modelContext)
                    }
                } label: {
                    Label("중지", systemImage: "stop.fill")
                }
                .primaryActionStyle(color: themeManager.stopButton)
            }
        }
        .frostedCard()
    }

    // MARK: - 파이차트 카운트다운

    @ViewBuilder
    private var countdownDisplay: some View {
        if isFlowmodoroFocus {
            VStack(spacing: Constants.Design.spacingSM) {
                PieChartTimerView(
                    progress: 0,
                    remainingTimeText: "▲ \(appState.timer.elapsedTime.formattedAsTimer)",
                    isPaused: appState.focusState == .paused,
                    activeColor: flowmodoroColor
                )
                Text("멈추면 \(estimatedBreakText) 휴식")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .opacity(breatheOpacity)
        } else {
            PieChartTimerView(
                progress: appState.timer.progress,
                remainingTimeText: appState.timer.remainingTime.formattedAsTimer,
                isPaused: appState.focusState == .paused,
                activeColor: phaseAccentColor
            )
            .opacity(breatheOpacity)
        }
    }

    // MARK: - 캡슐 프로그레스 바

    @ViewBuilder
    private var capsuleProgressBar: some View {
        if isFlowmodoroFocus {
            // 플로우모도로 집중 중: 진행률 없으므로 맥동 바
            Capsule()
                .fill(flowmodoroColor.opacity(0.2))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(flowmodoroColor)
                        .frame(width: 40)
                        .phaseAnimator([false, true]) { content, phase in
                            content
                                .offset(x: phase ? 260 : 0)
                                .opacity(phase ? 0.3 : 0.8)
                        } animation: { _ in
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
                        }
                }
                .clipShape(Capsule())
        } else {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [phaseAccentColor.opacity(0.7), phaseAccentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geometry.size.width * appState.timer.progress))
                        .animation(.easeInOut(duration: 0.8), value: appState.timer.progress)
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
        }
    }

    // MARK: - 상태 뱃지

    private var statusBadge: some View {
        VStack(spacing: Constants.Design.spacingXS) {
            if appState.timerMode == .flowmodoro {
                let isBreak = appState.currentFlowmodoroPhase == .rest
                HStack(spacing: 6) {
                    Image(systemName: isBreak ? "cup.and.saucer.fill" : "waveform.circle.fill")
                        .symbolEffect(.pulse, options: .repeating, isActive: !isBreak)
                    Text(LocalizedStringKey(isBreak ? "휴식 중" : "플로우 중"))
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(flowmodoroColor.opacity(0.12))
                .foregroundStyle(flowmodoroColor)
                .clipShape(Capsule())
                .shadow(color: flowmodoroColor.opacity(0.15), radius: 4, y: 1)
            } else if appState.timerMode == .pomodoro, let phase = appState.currentPomodoroPhase {
                HStack(spacing: 6) {
                    Image(systemName: phase.type == .focus ? "bolt.fill" : "cup.and.saucer.fill")
                        .symbolEffect(.pulse, options: .repeating, isActive: phase.type == .focus)
                    Text(phase.type.displayName)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(phaseAccentColor.opacity(0.12))
                .foregroundStyle(phaseAccentColor)
                .clipShape(Capsule())
                .shadow(color: phaseAccentColor.opacity(0.15), radius: 4, y: 1)
                .scaleEffect(phaseBadgeScale)

                Text(appState.pomodoroCycleProgressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if appState.focusState == .paused {
                HStack(spacing: 6) {
                    Image(systemName: "pause.fill")
                    Text("일시정지됨")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(themeManager.pauseButton.opacity(0.12))
                .foregroundStyle(themeManager.pauseButton)
                .clipShape(Capsule())
            } else {
                Text("집중 중...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 동기부여 명언 (v1.x)

    @ViewBuilder
    private var motivationQuote: some View {
        if settingsViewModel.showMotivationQuotes, let quote = focusQuote {
            Text(quote.text)
                .font(.caption.italic())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 의도 뱃지

    @ViewBuilder
    private var intentionBadge: some View {
        if let intention = appState.currentSession?.intention, !intention.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "target")
                    .font(.caption2)
                Text(intention)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(themeManager.primary.opacity(0.12), in: Capsule())
            .foregroundStyle(themeManager.primary)
        }
    }

    // MARK: - 시작 시간 뱃지

    @ViewBuilder
    private var startTimeBadge: some View {
        if let startedAt = appState.currentSession?.startedAt {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("\(startedAt.formatted(date: .omitted, time: .shortened)) 시작")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 컨트롤 버튼

    private var controlButtons: some View {
        VStack(spacing: Constants.Design.spacingSM) {
            HStack(spacing: Constants.Design.spacingMD) {
                if isFlowmodoroFocus {
                    // 플로우모도로 집중 중: "집중 완료" 주요 버튼
                    Button {
                        Task {
                            await appState.finishFlowmodoroFocus(modelContext: modelContext)
                        }
                    } label: {
                        Label("집중 완료", systemImage: "checkmark.circle.fill")
                    }
                    .primaryActionStyle(color: flowmodoroColor)

                    cancelButton
                } else {
                    Button {
                        withAnimation(.focusSpring) {
                            if appState.focusState == .paused {
                                appState.resumeSession()
                            } else {
                                appState.pauseSession()
                            }
                        }
                    } label: {
                        Label(
                            LocalizedStringKey(appState.focusState == .paused ? "재개" : "일시정지"),
                            systemImage: appState.focusState == .paused ? "play.fill" : "pause.fill"
                        )
                    }
                    .secondaryActionStyle(color: themeManager.pauseButton)

                    cancelButton
                }
            }

            // 취소 잠금 상태 표시
            cancelLockoutBadge
        }
    }

    // MARK: - 취소 강도별 버튼

    @ViewBuilder
    private var cancelButton: some View {
        switch appState.currentCancelIntensity {
        case 2:
            // 하드코어: 비상 해제만 가능
            if appState.isEmergencyUnlockActive {
                emergencyUnlockView
            } else {
                Button {
                    appState.requestEmergencyUnlock()
                } label: {
                    Label("비상 해제", systemImage: "exclamationmark.shield.fill")
                }
                .secondaryActionStyle(color: themeManager.stopButton)
                .disabled(appState.emergencyUnlockUsedToday)
            }
        case 1:
            // 강함: 잠금 시간 중에는 비활성
            Button {
                viewModel.requestStop()
            } label: {
                Label("중지", systemImage: "stop.fill")
            }
            .secondaryActionStyle(color: themeManager.stopButton)
            .disabled(!appState.canCancel)
        default:
            // 기본: 확인 다이얼로그
            Button {
                viewModel.requestStop()
            } label: {
                Label("중지", systemImage: "stop.fill")
            }
            .secondaryActionStyle(color: themeManager.stopButton)
        }
    }

    @ViewBuilder
    private var cancelLockoutBadge: some View {
        if appState.currentCancelIntensity == 1, !appState.canCancel {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("중지 잠금 \(Int(appState.cancelLockoutRemainingSeconds))초 남음")
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(themeManager.stopButton.opacity(0.7))
        } else if appState.currentCancelIntensity == 2 && !appState.isEmergencyUnlockActive {
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

    @ViewBuilder
    private var emergencyUnlockView: some View {
        VStack(spacing: Constants.Design.spacingSM) {
            if appState.emergencyUnlockCountdown > 0 {
                Text("\(Int(appState.emergencyUnlockCountdown))초 대기 중...")
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(themeManager.stopButton)

                Button {
                    appState.cancelEmergencyUnlock()
                } label: {
                    Label("취소", systemImage: "xmark")
                }
                .secondaryActionStyle(color: .secondary)
            } else {
                Button {
                    Task {
                        await appState.confirmEmergencyUnlock(modelContext: modelContext)
                    }
                } label: {
                    Label("비상 해제 확인", systemImage: "exclamationmark.triangle.fill")
                }
                .primaryActionStyle(color: themeManager.stopButton)
            }
        }
    }

    // MARK: - Helpers

    private var phaseAccentColor: Color {
        if appState.timerMode == .flowmodoro {
            return flowmodoroColor
        }
        guard appState.timerMode == .pomodoro,
              let phase = appState.currentPomodoroPhase else {
            return themeManager.progress
        }
        return phase.type == .focus ? themeManager.primary : themeManager.secondary
    }

    private var isFlowmodoroFocus: Bool {
        appState.timerMode == .flowmodoro && appState.currentFlowmodoroPhase == .focus
    }

    private var flowmodoroColor: Color {
        if appState.currentFlowmodoroPhase == .rest {
            return themeManager.secondary
        }
        return themeManager.primary
    }

    private var estimatedBreakText: String {
        let breakSeconds = appState.timer.elapsedTime * Constants.Timer.flowmodoroBreakRatio
        return max(breakSeconds, 1).formattedAsReadable
    }

    private func animatePhaseBadge() {
        phaseBadgeScale = 0.85
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            phaseBadgeScale = 1.12
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.15)) {
                phaseBadgeScale = 1.0
            }
        }
    }

    private func startBreatheAnimation() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            breatheOpacity = 0.6
        }
    }
}

// MARK: - 완료 콘텐츠 (v0.5 리디자인)

struct CompletedContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Query(
        filter: #Predicate<FocusSession> { $0.wasCompleted },
        sort: \FocusSession.startedAt,
        order: .reverse
    )
    private var sessions: [FocusSession]
    @State private var checkScale: CGFloat = 0
    @State private var showSummary = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var retrospectCompleted = false

    private var streakInfo: StreakCalculator.StreakInfo {
        StreakCalculator.calculate(from: sessions)
    }

    var body: some View {
        ZStack {
            VStack(spacing: Constants.Design.spacingXL) {
                celebrationIcon
                summaryContent
                completionQuote
                retrospectSection
                confirmButton
            }

            // 마일스톤 축하 오버레이 (v1.5)
            if let milestone = appState.pendingMilestone {
                MilestoneCelebrationView(
                    milestone: milestone,
                    onDismiss: { appState.pendingMilestone = nil }
                )
            }

            // 레벨업 축하 오버레이 (v1.x)
            if appState.pendingMilestone == nil, let newLevel = appState.pendingLevelUp {
                LevelUpCelebrationView(
                    newLevel: newLevel,
                    onDismiss: { appState.pendingLevelUp = nil }
                )
            }
        }
        .padding(.vertical, Constants.Design.spacingSM)
        .onAppear {
            playCelebration()
            appState.lastCompletedStreakInfo = streakInfo
        }
    }

    // MARK: - 완료 명언 (v1.x)

    @ViewBuilder
    private var completionQuote: some View {
        if settingsViewModel.showMotivationQuotes && showSummary {
            QuoteView()
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - 회고 섹션

    @ViewBuilder
    private var retrospectSection: some View {
        if settingsViewModel.showRetrospect && showSummary && !retrospectCompleted {
            RetrospectView(
                level: settingsViewModel.retrospectLevel,
                onComplete: { data in
                    appState.saveRetrospectFull(
                        emoji: data.emoji,
                        text: data.text,
                        rating: data.rating
                    )
                    retrospectCompleted = true
                },
                onSkip: {
                    retrospectCompleted = true
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - 축하 아이콘

    private var celebrationIcon: some View {
        ZStack {
            // 컨페티 파티클
            ForEach(confettiParticles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(particle.offset)
                    .opacity(particle.opacity)
            }

            // 외곽 글로우 링
            Circle()
                .fill(themeManager.completed.opacity(0.08))
                .frame(width: 80, height: 80)
                .scaleEffect(checkScale)

            // 체크마크
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(themeManager.completed)
                .scaleEffect(checkScale)
        }
        .frame(height: 90)
    }

    // MARK: - 요약 콘텐츠

    @ViewBuilder
    private var summaryContent: some View {
        if showSummary {
            VStack(spacing: Constants.Design.spacingMD) {
                Text("집중 완료!")
                    .font(.title3.bold())

                VStack(spacing: Constants.Design.spacingSM) {
                    if let intention = appState.lastCompletedIntention, !intention.isEmpty {
                        summaryRow(
                            icon: "target",
                            color: themeManager.accent,
                            text: intention
                        )
                    }

                    summaryRow(
                        icon: "clock.fill",
                        color: themeManager.primary,
                        text: appState.completedSummaryText
                    )

                    if let detailText = appState.completedDetailText {
                        summaryRow(
                            icon: "chart.bar.fill",
                            color: themeManager.secondary,
                            text: detailText
                        )
                    }

                    if streakInfo.current > 0 {
                        summaryRow(
                            icon: "flame.fill",
                            color: themeManager.warning,
                            text: String(localized: "\(streakInfo.current)일 연속 집중!")
                        )
                    }

                    if appState.lastCompletedXPEarned > 0 {
                        summaryRow(
                            icon: "star.fill",
                            color: themeManager.accent,
                            text: "+\(appState.lastCompletedXPEarned) XP"
                        )
                    }
                }
                .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func summaryRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            IconBadge(systemName: icon, color: color, size: 28)
            Text(LocalizedStringKey(text))
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - 확인 버튼

    @ViewBuilder
    private var confirmButton: some View {
        if showSummary {
            Button {
                withAnimation(.focusSpring) {
                    appState.resetToIdle()
                }
            } label: {
                Label("확인", systemImage: "checkmark")
            }
            .primaryActionStyle(color: themeManager.primary)
            .transition(.opacity)
        }
    }

    // MARK: - 축하 애니메이션

    private func playCelebration() {
        // 체크마크 스케일인
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
            checkScale = 1.0
        }

        // 컨페티 버스트
        spawnConfetti()

        // 요약 페이드인
        withAnimation(.mediumEase.delay(0.5)) {
            showSummary = true
        }
    }

    private func spawnConfetti() {
        let colors: [Color] = [
            themeManager.primary,
            themeManager.secondary,
            themeManager.accent,
            themeManager.completed,
        ]

        for i in 0..<12 {
            let angle = Double(i) * (360.0 / 12.0) * .pi / 180
            let distance: CGFloat = CGFloat.random(in: 30...50)
            let particle = ConfettiParticle(
                color: colors[i % colors.count],
                size: CGFloat.random(in: 4...7),
                offset: .zero,
                opacity: 0
            )
            confettiParticles.append(particle)

            let idx = confettiParticles.count - 1

            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                confettiParticles[idx].offset = CGSize(
                    width: cos(angle) * distance,
                    height: sin(angle) * distance
                )
                confettiParticles[idx].opacity = 1
            }

            withAnimation(.easeIn(duration: 0.3).delay(0.6)) {
                confettiParticles[idx].opacity = 0
            }
        }
    }
}

// MARK: - 컨페티 파티클

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var offset: CGSize
    var opacity: Double
}

// MARK: - Previews

#Preview("유휴 상태") {
    IdleContentView()
        .environment(AppState())
        .environment(ThemeManager.shared)
        .environment(SettingsViewModel())
        .environment(LicenseManager.shared)
        .frame(width: 340)
        .padding()
}

#Preview("집중 중") {
    FocusingContentView()
        .environment(AppState())
        .environment(ThemeManager.shared)
        .environment(SettingsViewModel())
        .frame(width: 340)
        .padding()
}

#Preview("완료") {
    CompletedContentView()
        .environment(AppState())
        .environment(ThemeManager.shared)
        .environment(SettingsViewModel())
        .frame(width: 340)
        .padding()
}
