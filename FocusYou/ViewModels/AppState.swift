import AppKit
import SwiftUI
import SwiftData
import WidgetKit
import os

// MARK: - 전역 앱 상태
// 타이머, 차단, 세션을 통합 관리하는 중앙 상태

@MainActor
@Observable
final class AppState {

    /// AppIntents, Widget 등 외부에서 접근하기 위한 약한 참조
    static weak var shared: AppState?

    // MARK: - 집중 상태

    enum FocusState: Sendable {
        case idle
        case focusing
        case paused
        case completed
    }

    enum TimerMode: String, Sendable {
        case free
        case pomodoro
        case flowmodoro
    }

    private(set) var focusState: FocusState = .idle
    private(set) var isBlockingActive = false
    private(set) var timerMode: TimerMode = .free
    private(set) var currentPomodoroPhase: PomodoroEngine.Phase?
    private(set) var pomodoroCycleProgressText = ""
    private(set) var activeProfileID: PersistentIdentifier?
    private(set) var lastCompletedMode: TimerMode = .free
    private(set) var lastCompletedFocusDuration: TimeInterval = 0
    private(set) var lastCompletedPomodoroCycles = 0
    private(set) var lastCompletedPomodoroBreakDuration: TimeInterval = 0
    private(set) var lastCompletedFlowmodoroBreakDuration: TimeInterval = 0
    var lastCompletedStreakInfo: StreakCalculator.StreakInfo?

    /// 완료된 세션 (회고 저장용, resetToIdle 시 nil)
    private(set) var completedSession: FocusSession?

    /// 완료된 세션의 의도 (UI 표시용)
    private(set) var lastCompletedIntention: String?

    /// 마일스톤 축하 표시 (v1.5)
    var pendingMilestone: Milestone?

    /// 레벨업 축하 표시 (v1.x)
    var pendingLevelUp: Int?

    /// 직전 레벨 (레벨업 감지용, 0 = 초기화 전)
    private var previousLevel: Int = 0

    /// 완료 세션에서 획득한 XP
    private(set) var lastCompletedXPEarned: Int = 0

    /// 현재 세션
    private(set) var currentSession: FocusSession?

    /// 에러 메시지 (alert용)
    var errorMessage: String?
    var showError = false
    var canRetryBlockingDeactivation = false

    /// Pro 구독 여부 (v2.0)
    var isPro: Bool { LicenseManager.shared.isPro }

    /// Private Relay 경고 표시 여부
    var showPrivateRelayWarning = false
    private var privateRelayWarningDismissedThisSession = false

    // MARK: - 취소 강도 (v1.3)

    private(set) var sessionStartedAt: Date?
    private(set) var currentCancelIntensity: Int = 0
    private(set) var currentCancelLockoutMinutes: Int = 0
    private(set) var emergencyUnlockCountdown: TimeInterval = 0
    private(set) var isEmergencyUnlockActive = false
    private var emergencyUnlockTimer: Timer?

    /// 취소 가능 여부 (취소 강도별 로직)
    var canCancel: Bool {
        switch currentCancelIntensity {
        case 0:
            return true
        case 1:
            return cancelLockoutRemainingSeconds <= 0
        default:
            return false
        }
    }

    /// Level 1: 잠금 남은 시간 (초)
    var cancelLockoutRemainingSeconds: TimeInterval {
        guard currentCancelIntensity == 1,
              let startedAt = sessionStartedAt else { return 0 }
        let elapsed = Date().timeIntervalSince(startedAt)
        let lockoutSeconds = TimeInterval(currentCancelLockoutMinutes * 60)
        return max(0, lockoutSeconds - elapsed)
    }

    /// Level 2: 오늘 비상 해제 사용 여부
    var emergencyUnlockUsedToday: Bool {
        guard let lastUsed = UserDefaults.standard.object(
            forKey: "emergencyUnlockLastUsedDate"
        ) as? Date else { return false }
        return Calendar.current.isDateInToday(lastUsed)
    }

    // MARK: - 타이머

    let timer = FreeTimer()
    private let pomodoroEngine = PomodoroEngine()
    private let flowmodoroEngine = FlowmodoroEngine()
    private(set) var currentFlowmodoroPhase: FlowmodoroEngine.PhaseType?
    private var accumulatedPomodoroFocusDuration: TimeInterval = 0
    private var sessionBlockedDomains: [String] = []
    private var sessionBlockedAppBundleIds: [String] = []
    private var sessionBlocklistMode: String = "blocklist"

    // MARK: - 메뉴바

    var menuBarIcon: String {
        isBlockingActive ? Constants.UI.menuBarIconActive : Constants.UI.menuBarIconIdle
    }

    var pomodoroPhaseTitle: String {
        guard timerMode == .pomodoro, let phase = currentPomodoroPhase else { return "" }
        return phase.type.displayName
    }

    var completedSummaryText: String {
        switch lastCompletedMode {
        case .pomodoro:
            return String(localized: "completed_pomodoro_summary \(lastCompletedFocusDuration.formattedAsReadable) \(lastCompletedPomodoroCycles)")
        case .flowmodoro:
            return String(localized: "completed_flowmodoro_summary \(lastCompletedFocusDuration.formattedAsReadable)")
        case .free:
            return String(localized: "completed_free_summary \(lastCompletedFocusDuration.formattedAsReadable)")
        }
    }

    var completedDetailText: String? {
        switch lastCompletedMode {
        case .pomodoro:
            return String(localized: "completed_pomodoro_break \(lastCompletedPomodoroBreakDuration.formattedAsReadable)")
        case .flowmodoro:
            return String(localized: "completed_flowmodoro_break \(lastCompletedFlowmodoroBreakDuration.formattedAsReadable)")
        case .free:
            return nil
        }
    }

    var completedStreakText: String? {
        guard let info = lastCompletedStreakInfo, info.current > 0 else { return nil }
        return String(localized: "completed_streak \(info.current)")
    }

    // MARK: - Private

    private let blockingCoordinator: any BlockingCoordinating
    private let notificationService: any NotificationServicing

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "AppState"
    )

    // MARK: - 초기화

    init(
        blockingCoordinator: any BlockingCoordinating = BlockingCoordinator.shared,
        notificationService: any NotificationServicing = NotificationService.shared,
        shouldRequestNotificationPermission: Bool = true,
        shouldRunStartupCleanup: Bool = true
    ) {
        self.blockingCoordinator = blockingCoordinator
        self.notificationService = notificationService

        // 타이머 완료 콜백 설정
        timer.onComplete = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleTimerComplete()
            }
        }

        // 알림 권한 요청
        if shouldRequestNotificationPermission {
            Task {
                _ = await notificationService.requestPermission()
            }
        }

        // 앱 시작 시 긴급 정리 확인
        if shouldRunStartupCleanup {
            Task { @MainActor [weak self] in
                guard let self else { return }
                await blockingCoordinator.emergencyCleanup()

                if case .error(let cleanupError) = await blockingCoordinator.state {
                    self.logger.error("앱 시작 시 긴급 정리 실패: \(cleanupError.localizedDescription)")
                    self.presentError(
                        String(localized: "error_startup_cleanup_failed \(cleanupError.localizedDescription)"),
                        canRetryDeactivation: true
                    )
                }
            }
        }

        // AppIntents, Widget 등 외부 접근용
        Self.shared = self
    }

    // MARK: - 집중 세션 시작

    func startFocusSession(
        duration: TimeInterval,
        sites: [BlockedSite],
        apps: [BlockedApp],
        modelContext: ModelContext,
        mode: TimerMode = .free,
        pomodoroConfiguration: PomodoroConfiguration = .default,
        intention: String? = nil,
        blocklistMode: String = "blocklist",
        cancelIntensity: Int = 0,
        cancelLockoutMinutes: Int = 5
    ) async {
        guard focusState == .idle else {
            logger.warning("세션 시작 실패: 이미 진행 중")
            return
        }

        logger.info("집중 세션 시작: \(mode.rawValue, privacy: .public), \(Int(duration))초")

        if mode == .pomodoro,
           PomodoroEngine.buildPhases(configuration: pomodoroConfiguration).isEmpty {
            presentError(String(localized: "error_invalid_pomodoro_config"))
            return
        }

        do {
            // 1. 차단 활성화 (키워드 패턴 확장 포함)
            let enabledDomains = sites.filter(\.isEnabled).flatMap { site -> [String] in
                if site.isKeywordPattern ?? false {
                    return HostsFileManager.shared.expandKeywordPattern(site.domain)
                }
                return [site.domain]
            }
            let effectiveBundleIds = apps.filter(\.isEnabled).map(\.bundleId)

            logger.info("차단 대상: 사이트 \(enabledDomains.count)개, 앱 \(effectiveBundleIds.count)개, 모드: \(blocklistMode)")

            if enabledDomains.isEmpty && effectiveBundleIds.isEmpty {
                logger.warning("차단 목록이 비어있음 — 차단 없이 타이머만 시작")
            }

            try await blockingCoordinator.activateBlocking(
                domains: enabledDomains,
                appBundleIds: effectiveBundleIds,
                blocklistMode: blocklistMode
            )
            isBlockingActive = !enabledDomains.isEmpty || !effectiveBundleIds.isEmpty
            sessionBlockedDomains = enabledDomains
            sessionBlockedAppBundleIds = effectiveBundleIds
            sessionBlocklistMode = blocklistMode

            // Private Relay 경고 (웹 차단 + 미닫힘)
            if isBlockingActive && !enabledDomains.isEmpty
               && !privateRelayWarningDismissedThisSession {
                if PrivateRelayDetector.detect() == .enabled {
                    showPrivateRelayWarning = true
                }
            }

            // 2. 타이머 시작
            timerMode = mode
            accumulatedPomodoroFocusDuration = 0
            currentPomodoroPhase = nil
            pomodoroCycleProgressText = ""

            switch mode {
            case .free:
                timer.start(duration: debugScaledDuration(duration))
            case .pomodoro:
                let firstPhase = pomodoroEngine.start(configuration: pomodoroConfiguration)
                guard let firstPhase else { return }
                currentPomodoroPhase = firstPhase
                pomodoroCycleProgressText = String(localized: "pomodoro_cycle_progress \(firstPhase.cycleIndex) \(pomodoroConfiguration.cycles)")
                timer.start(duration: debugScaledDuration(firstPhase.duration))
            case .flowmodoro:
                flowmodoroEngine.startFocus()
                currentFlowmodoroPhase = .focus
                timer.start(duration: debugScaledDuration(Constants.Timer.flowmodoroMaxDuration))
            }

            // 3. 세션 기록 생성
            let session = FocusSession(
                timerMode: mode.rawValue,
                plannedDuration: plannedDuration(
                    mode: mode,
                    freeDuration: duration,
                    pomodoroConfiguration: pomodoroConfiguration
                )
            )
            modelContext.insert(session)
            currentSession = session
            currentSession?.intention = intention

            // 4. 취소 강도 설정
            sessionStartedAt = .now
            currentCancelIntensity = cancelIntensity
            currentCancelLockoutMinutes = cancelLockoutMinutes

            // 5. 상태 전환
            focusState = .focusing

            // 6. 앰비언트 사운드
            await startAmbientSoundIfEnabled()

            // 7. Widget 데이터 공유
            updateSharedData()

            logger.info("집중 세션 시작 완료")

        } catch let error as FocusYouError {
            logger.error("세션 시작 실패: \(error.localizedDescription)")

            if case .authorizationCancelled = error {
                // 사용자가 비밀번호 입력을 취소한 경우 조용히 처리
                return
            }

            presentError(error.localizedDescription)
        } catch {
            logger.error("세션 시작 실패 (알 수 없는 에러): \(error.localizedDescription)")
            presentError(error.localizedDescription)
        }
    }

    // MARK: - 프로필 기반 원클릭 시작

    /// 프로필의 타이머 설정으로 즉시 세션 시작
    func startSessionFromProfile(
        _ profile: BlockProfile,
        modelContext: ModelContext
    ) async {
        setActiveProfile(profile)

        let mode: TimerMode = switch profile.timerMode {
        case "pomodoro": .pomodoro
        case "flowmodoro": .flowmodoro
        default: .free
        }

        let pomodoroConfig = PomodoroConfiguration(
            focusMinutes: profile.focusDuration / 60,
            shortBreakMinutes: profile.breakDuration / 60,
            longBreakMinutes: profile.longBreakDuration / 60,
            cycles: profile.pomodoroCount
        )

        let duration: TimeInterval = switch mode {
        case .free: TimeInterval(profile.focusDuration)
        case .pomodoro: TimeInterval(pomodoroConfig.focusMinutes * 60)
        case .flowmodoro: Constants.Timer.flowmodoroMaxDuration
        }

        let profileSites = profile.blockedSites.filter(\.isEnabled)
        let profileApps = profile.blockedApps.filter(\.isEnabled)

        if profileSites.isEmpty && profileApps.isEmpty {
            logger.warning("프로필 '\(profile.name, privacy: .public)'에 활성 차단 항목 없음 — 타이머만 시작")
        }

        await startFocusSession(
            duration: duration,
            sites: profileSites,
            apps: profileApps,
            modelContext: modelContext,
            mode: mode,
            pomodoroConfiguration: pomodoroConfig,
            blocklistMode: profile.blocklistMode ?? "blocklist",
            cancelIntensity: profile.cancelIntensity ?? 0,
            cancelLockoutMinutes: profile.cancelLockoutMinutes ?? 5
        )

        currentSession?.profileName = profile.name
    }

    // MARK: - 일시정지 / 재개

    func pauseSession() {
        guard focusState == .focusing else { return }
        timer.pause()
        focusState = .paused
        Task { await pauseAmbientSound() }
        logger.info("세션 일시정지")
    }

    func resumeSession() {
        guard focusState == .paused else { return }
        timer.resume()
        focusState = .focusing
        Task { await resumeAmbientSound() }
        logger.info("세션 재개")
    }

    // MARK: - 세션 중지 (취소)

    func stopSession(modelContext: ModelContext) async {
        guard focusState == .focusing || focusState == .paused else { return }
        logger.info("세션 중지 (사용자 취소)")
        let wasBlockingActive = isBlockingActive

        // 타이머 정지
        let elapsed = Int(sessionElapsedDuration)
        timer.stop()
        await stopAmbientSound()

        // 차단 해제
        await safelyDeactivateBlocking(
            shouldNotify: wasBlockingActive,
            fallbackBlockingState: wasBlockingActive
        ) { String(localized: "error_deactivation_failed \($0)") }

        // 세션 기록 업데이트
        currentSession?.cancel(actualDuration: elapsed)
        currentSession = nil
        endFlowmodoroIfNeeded()
        endPomodoroIfNeeded()
        resetCancelIntensityState()

        focusState = .idle
        updateSharedData()
    }

    // MARK: - 타이머 완료 처리

    private func handleTimerComplete() async {
        switch timerMode {
        case .free:
            logger.info("자유 타이머 완료 → 세션 종료 처리")
            await finalizeSessionAfterCompletion(
                notificationDuration: timer.totalDuration,
                actualDuration: Int(timer.totalDuration)
            )
        case .pomodoro:
            await handlePomodoroPhaseCompletion()
        case .flowmodoro:
            await handleFlowmodoroCompletion()
        }
    }

    private func handlePomodoroPhaseCompletion() async {
        guard let completedPhase = currentPomodoroPhase else {
            await finalizeSessionAfterCompletion(
                notificationDuration: timer.totalDuration,
                actualDuration: Int(timer.totalDuration)
            )
            return
        }

        logger.info("뽀모도로 페이즈 완료: \(completedPhase.type.rawValue, privacy: .public)")

        if completedPhase.type == .focus {
            accumulatedPomodoroFocusDuration += completedPhase.duration
        }
        // 페이즈 경계(완료 시점)에서는 누적 집중 시간이 이미 최종값.
        // sessionElapsedDuration을 쓰면 완료된 focus 페이즈가 이중 계산될 수 있다.
        let completedFocusSeconds = Int(accumulatedPomodoroFocusDuration)

        if let nextPhase = pomodoroEngine.advancePhase() {
            do {
                try await applyBlockingForPomodoroPhase(nextPhase.type)
            } catch let phaseTransitionError {
                logger.error("뽀모도로 페이즈 전환 차단 처리 실패: \(phaseTransitionError.localizedDescription)")

                if nextPhase.type == .focus {
                    var cleanupError: Error?
                    do {
                        try await blockingCoordinator.deactivateBlocking()
                        isBlockingActive = false
                    } catch {
                        cleanupError = error
                        isBlockingActive = true
                        logger.error("집중 단계 전환 실패 후 차단 정리 실패: \(error.localizedDescription)")
                    }

                    if let cleanupError {
                        presentError(
                            String(localized: "error_phase_activation_and_cleanup_failed \(phaseTransitionError.localizedDescription) \(cleanupError.localizedDescription)"),
                            canRetryDeactivation: true
                        )
                    } else {
                        presentError(
                            String(localized: "error_phase_activation_failed \(phaseTransitionError.localizedDescription)")
                        )
                    }

                    currentSession?.cancel(actualDuration: completedFocusSeconds)
                    currentSession = nil
                    timer.reset()
                    endPomodoroIfNeeded()
                    focusState = .idle
                    return
                } else {
                    // 휴식 단계 차단 해제 실패 시에도 세션 정리
                    presentError(
                        String(localized: "error_break_deactivation_failed \(phaseTransitionError.localizedDescription)"),
                        canRetryDeactivation: true
                    )
                    currentSession?.cancel(actualDuration: completedFocusSeconds)
                    currentSession = nil
                    timer.reset()
                    endPomodoroIfNeeded()
                    focusState = .idle
                    return
                }
            }

            currentPomodoroPhase = nextPhase
            pomodoroCycleProgressText = String(localized: "pomodoro_cycle_progress \(nextPhase.cycleIndex) \(pomodoroEngine.configuration.cycles)")

            // 뽀모도로 페이즈별 앰비언트 사운드 전환
            if nextPhase.type == .focus {
                await startAmbientSoundIfEnabled()
            } else {
                await stopAmbientSound()
            }

            // completed 상태의 FreeTimer를 다음 페이즈 재시작을 위해 초기화
            timer.reset()
            timer.start(duration: debugScaledDuration(nextPhase.duration))
            await notificationService.sendPomodoroPhaseStarted(
                phaseTitle: nextPhase.type.displayName,
                cycleText: pomodoroCycleProgressText
            )
            focusState = .focusing
            return
        }

        await finalizeSessionAfterCompletion(
            notificationDuration: accumulatedPomodoroFocusDuration,
            actualDuration: Int(accumulatedPomodoroFocusDuration)
        )
    }

    // MARK: - 플로우모도로

    /// 사용자가 "집중 완료"를 누를 때 호출 — 집중 종료 → 자동 휴식 전환
    func finishFlowmodoroFocus(modelContext: ModelContext) async {
        guard timerMode == .flowmodoro,
              focusState == .focusing || focusState == .paused else { return }

        let focusElapsed = timer.elapsedTime
        logger.info("플로우모도로 집중 완료: \(Int(focusElapsed))초")
        timer.stop()
        await stopAmbientSound()

        // 휴식 계산
        let breakDuration = flowmodoroEngine.finishFocusAndStartBreak(elapsed: focusElapsed)
        currentFlowmodoroPhase = .rest

        // 차단 해제
        await safelyDeactivateBlocking(
            shouldNotify: false,
            fallbackBlockingState: true
        ) { String(localized: "error_flowmodoro_break_deactivation_failed \($0)") }

        // 휴식 카운트다운 시작
        timer.reset()
        timer.start(duration: debugScaledDuration(breakDuration))
        focusState = .focusing
        await notificationService.sendPomodoroPhaseStarted(
            phaseTitle: String(localized: "flowmodoro_rest_phase"),
            cycleText: String(localized: "flowmodoro_rest_seconds \(Int(breakDuration))")
        )
    }

    private func handleFlowmodoroCompletion() async {
        if currentFlowmodoroPhase == .rest {
            // 휴식 완료 → 세션 마무리
            logger.info("플로우모도로 휴식 완료 → 세션 종료 처리")
            flowmodoroEngine.completeBreak()
            await finalizeSessionAfterCompletion(
                notificationDuration: flowmodoroEngine.focusDuration,
                actualDuration: Int(flowmodoroEngine.focusDuration)
            )
        } else {
            // focus 페이즈 4시간 캡 도달 — 드물지만 정상 종료
            logger.info("플로우모도로 최대 집중 시간 도달 → 세션 종료 처리")
            let elapsed = timer.elapsedTime
            flowmodoroEngine.finishFocusAndStartBreak(elapsed: elapsed)
            flowmodoroEngine.completeBreak()
            await finalizeSessionAfterCompletion(
                notificationDuration: elapsed,
                actualDuration: Int(elapsed)
            )
        }
    }

    private func finalizeSessionAfterCompletion(
        notificationDuration: TimeInterval,
        actualDuration: Int
    ) async {
        let wasBlockingActive = isBlockingActive
        let completedMode = timerMode
        let completedPomodoroCycles = pomodoroEngine.configuration.cycles
        let completedPomodoroBreakDuration = pomodoroBreakDuration(
            configuration: pomodoroEngine.configuration
        )

        // 1. 완료 알림 + 사운드 정지
        await notificationService.sendTimerCompleted(
            duration: notificationDuration
        )
        await stopAmbientSound()

        // 2. 차단 해제
        await safelyDeactivateBlocking(
            shouldNotify: wasBlockingActive,
            fallbackBlockingState: wasBlockingActive
        ) { String(localized: "error_completion_deactivation_failed \($0)") }

        // 3. 세션 기록
        currentSession?.complete(actualDuration: actualDuration)
        completedSession = currentSession
        lastCompletedIntention = currentSession?.intention
        currentSession = nil

        lastCompletedMode = completedMode
        lastCompletedFocusDuration = TimeInterval(actualDuration)
        lastCompletedPomodoroCycles = completedMode == .pomodoro ? completedPomodoroCycles : 0
        lastCompletedPomodoroBreakDuration = completedMode == .pomodoro
            ? completedPomodoroBreakDuration
            : 0
        lastCompletedFlowmodoroBreakDuration = completedMode == .flowmodoro
            ? flowmodoroEngine.breakDuration
            : 0

        endFlowmodoroIfNeeded()
        endPomodoroIfNeeded()

        // 4. Apple Calendar 동기화 (v1.3)
        if UserDefaults.standard.bool(forKey: Constants.Settings.enableCalendarSyncKey),
           let session = completedSession {
            Task {
                if let eventID = await CalendarSyncService.shared.createEvent(for: session) {
                    session.calendarEventID = eventID
                }
            }
        }

        // 5. 마일스톤 체크 (v1.5)
        if let context = completedSession?.modelContext {
            checkMilestones(modelContext: context)
        }

        // 6. 상태 전환
        focusState = .completed
    }

    private func plannedDuration(
        mode: TimerMode,
        freeDuration: TimeInterval,
        pomodoroConfiguration: PomodoroConfiguration
    ) -> Int? {
        switch mode {
        case .free:
            return Int(freeDuration)
        case .pomodoro:
            return Int(pomodoroConfiguration.plannedFocusDuration)
        case .flowmodoro:
            return nil
        }
    }

    private var sessionElapsedDuration: TimeInterval {
        switch timerMode {
        case .free:
            return timer.elapsedTime
        case .pomodoro:
            guard let currentPhase = currentPomodoroPhase else {
                return accumulatedPomodoroFocusDuration
            }
            if currentPhase.type == .focus {
                return accumulatedPomodoroFocusDuration + timer.elapsedTime
            }
            return accumulatedPomodoroFocusDuration
        case .flowmodoro:
            if currentFlowmodoroPhase == .focus {
                return timer.elapsedTime
            }
            return flowmodoroEngine.focusDuration
        }
    }

    private func applyBlockingForPomodoroPhase(_ phaseType: PomodoroEngine.PhaseType) async throws {
        let hasBlockingTargets = !sessionBlockedDomains.isEmpty || !sessionBlockedAppBundleIds.isEmpty

        guard hasBlockingTargets else {
            isBlockingActive = false
            return
        }

        switch phaseType {
        case .focus:
            try await blockingCoordinator.activateBlocking(
                domains: sessionBlockedDomains,
                appBundleIds: sessionBlockedAppBundleIds,
                blocklistMode: sessionBlocklistMode
            )
            isBlockingActive = true
        case .shortBreak, .longBreak:
            try await blockingCoordinator.deactivateBlocking()
            isBlockingActive = false
        }
    }

    private func endPomodoroIfNeeded() {
        if timerMode == .pomodoro {
            pomodoroEngine.reset()
        }
        // 공통 세션 정리
        timerMode = .free
        currentPomodoroPhase = nil
        pomodoroCycleProgressText = ""
        accumulatedPomodoroFocusDuration = 0
        sessionBlockedDomains = []
        sessionBlockedAppBundleIds = []
        sessionBlocklistMode = "blocklist"
    }

    private func endFlowmodoroIfNeeded() {
        if timerMode == .flowmodoro {
            flowmodoroEngine.reset()
            currentFlowmodoroPhase = nil
        }
    }

    private func pomodoroBreakDuration(configuration: PomodoroConfiguration) -> TimeInterval {
        guard configuration.cycles > 0 else { return 0 }

        let shortBreakCount = max(configuration.cycles - 1, 0)
        let totalBreakMinutes = (shortBreakCount * configuration.shortBreakMinutes) + configuration.longBreakMinutes
        return TimeInterval(totalBreakMinutes * 60)
    }

    #if DEBUG
    private func debugScaledDuration(_ seconds: TimeInterval) -> TimeInterval {
        let defaults = UserDefaults.standard

        guard defaults.bool(forKey: Constants.Settings.debugFastTimerEnabledKey) else {
            return seconds
        }

        let configuredValue = defaults.object(forKey: Constants.Settings.debugSecondsPerMinuteKey) == nil
            ? Constants.Settings.debugSecondsPerMinuteDefault
            : defaults.double(forKey: Constants.Settings.debugSecondsPerMinuteKey)
        let normalizedSecondsPerMinute = max(1, configuredValue)
        return (seconds / 60.0) * normalizedSecondsPerMinute
    }
    #else
    private func debugScaledDuration(_ seconds: TimeInterval) -> TimeInterval {
        seconds
    }
    #endif

    /// 완료 상태에서 유휴로 복귀
    func resetToIdle() {
        timer.reset()
        endFlowmodoroIfNeeded()
        endPomodoroIfNeeded()
        resetCancelIntensityState()
        lastCompletedMode = .free
        lastCompletedFocusDuration = 0
        lastCompletedPomodoroCycles = 0
        lastCompletedPomodoroBreakDuration = 0
        lastCompletedFlowmodoroBreakDuration = 0
        lastCompletedStreakInfo = nil
        completedSession = nil
        lastCompletedIntention = nil
        lastCompletedXPEarned = 0
        pendingLevelUp = nil
        focusState = .idle
        updateSharedData()
    }

    /// 회고 이모지 저장 (완료 화면에서 호출)
    func saveRetrospectEmoji(_ emoji: String) {
        completedSession?.retrospectEmoji = emoji
        logger.info("회고 이모지 저장: \(emoji)")
    }

    /// 회고 전체 데이터 저장 (Level 2-3용)
    func saveRetrospectFull(emoji: String?, text: String?, rating: Int?) {
        completedSession?.retrospectEmoji = emoji
        completedSession?.retrospectText = text
        completedSession?.retrospectRating = rating
        logger.info("회고 저장 완료")
    }

    // MARK: - 마일스톤 체크 (v1.5)

    private func checkMilestones(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<FocusSession>()
        let allSessions: [FocusSession]
        do {
            allSessions = try modelContext.fetch(descriptor)
        } catch {
            logger.error("마일스톤 체크 실패 — 세션 fetch 에러: \(error.localizedDescription)")
            return
        }

        let completedSessions = allSessions.filter { $0.wasCompleted }
        let totalHours = Double(completedSessions.reduce(0) { $0 + $1.actualDuration }) / 3600.0
        let totalSessions = completedSessions.count
        let streakDays = StreakCalculator.calculate(from: allSessions).current

        let newMilestones = MilestoneDetector.checkMilestones(
            streakDays: streakDays,
            totalHours: totalHours,
            totalSessions: totalSessions
        )

        if !newMilestones.isEmpty {
            MilestoneDetector.saveBadges(newMilestones, modelContext: modelContext)
            pendingMilestone = newMilestones.first
        }

        // 레벨업 감지 (v1.x)
        let xpInfo = LevelManager.xpInfo(from: allSessions)
        let newLevel = xpInfo.level

        // 완료 세션의 XP 계산
        if let session = completedSession, session.wasCompleted {
            let focusMinutes = Double(session.actualDuration) / 60.0
            lastCompletedXPEarned = LevelManager.xpForSession(
                focusMinutes: focusMinutes,
                wasCompleted: true,
                currentStreakDays: streakDays
            )
        }

        if previousLevel == 0 {
            // 첫 호출: 초기화만 (축하 방지)
            previousLevel = newLevel
        } else if newLevel > previousLevel {
            pendingLevelUp = newLevel
            previousLevel = newLevel
            logger.info("레벨업 감지: \(newLevel)")
        }
    }

    // MARK: - 앰비언트 사운드

    private func startAmbientSoundIfEnabled() async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Constants.Settings.enableAmbientSoundKey) else { return }

        let trackRaw = defaults.string(forKey: Constants.Settings.ambientSoundTrackKey)
            ?? Constants.Settings.ambientSoundTrackDefault
        let volume = defaults.double(forKey: Constants.Settings.ambientSoundVolumeKey)
        let track = AmbientSoundTrack(rawValue: trackRaw) ?? .whiteNoise
        let effectiveVolume = volume > 0 ? Float(volume) : Float(Constants.Settings.ambientSoundVolumeDefault)

        await AmbientSoundManager.shared.play(track: track, volume: effectiveVolume)
    }

    private func stopAmbientSound() async {
        await AmbientSoundManager.shared.stop()
    }

    private func pauseAmbientSound() async {
        await AmbientSoundManager.shared.pause()
    }

    private func resumeAmbientSound() async {
        await AmbientSoundManager.shared.resume()
    }

    /// 차단 해제 재시도 (오류 UI의 재시도 버튼에서 호출)
    func retryBlockingDeactivation() async {
        guard canRetryBlockingDeactivation else { return }

        let success = await safelyDeactivateBlocking(
            shouldNotify: isBlockingActive,
            fallbackBlockingState: true
        ) { String(localized: "error_retry_deactivation_failed \($0)") }

        if success {
            dismissError()
        }
    }

    /// 인라인 에러 표시 닫기
    func dismissError() {
        showError = false
        errorMessage = nil
        canRetryBlockingDeactivation = false
    }

    // MARK: - Private Relay 경고 액션

    /// Private Relay 경고를 닫고 이번 세션 내 재표시를 방지합니다.
    func dismissPrivateRelayWarning() {
        showPrivateRelayWarning = false
        privateRelayWarningDismissedThisSession = true
    }

    /// 경고에서 "Private Relay 설정 열기" 선택 시 — 시스템 설정으로 이동
    func openPrivateRelaySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane") {
            NSWorkspace.shared.open(url)
        }
        dismissPrivateRelayWarning()
    }

    /// 공통 에러 표시 헬퍼
    private func presentError(
        _ message: String,
        canRetryDeactivation: Bool = false
    ) {
        errorMessage = message
        canRetryBlockingDeactivation = canRetryDeactivation
        showError = true
    }

    /// 차단 해제 공통 헬퍼 — 에러 처리 + 알림 + 상태 복원 패턴 통합
    @discardableResult
    private func safelyDeactivateBlocking(
        shouldNotify: Bool,
        fallbackBlockingState: Bool,
        formatError: (String) -> String
    ) async -> Bool {
        do {
            try await blockingCoordinator.deactivateBlocking()
            if shouldNotify {
                await notificationService.sendBlockingDeactivated()
            }
            isBlockingActive = false
            return true
        } catch {
            let desc = error.localizedDescription
            logger.error("차단 해제 실패: \(desc)")
            isBlockingActive = fallbackBlockingState
            presentError(formatError(desc), canRetryDeactivation: true)
            return false
        }
    }

    // MARK: - 취소 강도 액션 (v1.3)

    /// Level 2: 비상 해제 요청 (2분 카운트다운 시작)
    func requestEmergencyUnlock() {
        guard currentCancelIntensity >= 2,
              !emergencyUnlockUsedToday else { return }

        isEmergencyUnlockActive = true
        emergencyUnlockCountdown = Constants.CancelIntensity.emergencyUnlockDuration

        emergencyUnlockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.emergencyUnlockCountdown -= 1
                if self.emergencyUnlockCountdown <= 0 {
                    self.emergencyUnlockTimer?.invalidate()
                    self.emergencyUnlockTimer = nil
                }
            }
        }

        logger.info("비상 해제 카운트다운 시작")
    }

    /// 비상 해제 카운트다운 취소
    func cancelEmergencyUnlock() {
        emergencyUnlockTimer?.invalidate()
        emergencyUnlockTimer = nil
        isEmergencyUnlockActive = false
        emergencyUnlockCountdown = 0
        logger.info("비상 해제 취소")
    }

    /// 비상 해제 확인 (카운트다운 완료 후 세션 중지)
    func confirmEmergencyUnlock(modelContext: ModelContext) async {
        guard currentCancelIntensity >= 2,
              emergencyUnlockCountdown <= 0,
              isEmergencyUnlockActive else { return }

        // 오늘 사용 기록
        UserDefaults.standard.set(Date(), forKey: "emergencyUnlockLastUsedDate")
        isEmergencyUnlockActive = false
        emergencyUnlockTimer?.invalidate()
        emergencyUnlockTimer = nil

        logger.info("비상 해제 확인 — 세션 강제 중지")
        await stopSession(modelContext: modelContext)
    }

    /// 취소 강도 상태 초기화
    private func resetCancelIntensityState() {
        sessionStartedAt = nil
        currentCancelIntensity = 0
        currentCancelLockoutMinutes = 0
        emergencyUnlockCountdown = 0
        isEmergencyUnlockActive = false
        emergencyUnlockTimer?.invalidate()
        emergencyUnlockTimer = nil
    }

    // MARK: - 활성 프로필

    func setActiveProfile(_ profile: BlockProfile?) {
        activeProfileID = profile?.persistentModelID
    }

    func ensureActiveProfile(in profiles: [BlockProfile]) {
        guard !profiles.isEmpty else {
            activeProfileID = nil
            return
        }

        if let activeProfileID,
           profiles.contains(where: { $0.persistentModelID == activeProfileID }) {
            return
        }

        if let defaultProfile = profiles.first(where: \.isDefault) {
            activeProfileID = defaultProfile.persistentModelID
            return
        }

        activeProfileID = profiles.first?.persistentModelID
    }

    func activeProfile(from profiles: [BlockProfile]) -> BlockProfile? {
        guard let activeProfileID else { return nil }
        return profiles.first(where: { $0.persistentModelID == activeProfileID })
    }

    // MARK: - Widget 데이터 공유 (v1.4)

    /// 위젯에 현재 상태 전달 (세션 시작/종료/타이머 변경 시 호출)
    func updateSharedData() {
        let themeManager = ThemeManager.shared
        let remaining: Int
        let total: Int

        switch timerMode {
        case .free:
            remaining = Int(timer.remainingTime)
            total = Int(timer.totalDuration)
        case .pomodoro:
            remaining = Int(timer.remainingTime)
            total = Int(timer.totalDuration)
        case .flowmodoro:
            remaining = Int(timer.remainingTime)
            total = Int(timer.totalDuration)
        }

        let data = SharedFocusData(
            isFocusing: focusState == .focusing,
            timerMode: timerMode.rawValue,
            remainingSeconds: remaining,
            totalSeconds: total,
            currentStreak: lastCompletedStreakInfo?.current ?? 0,
            longestStreak: lastCompletedStreakInfo?.longest ?? 0,
            todayFocusMinutes: 0,
            todaySessionCount: 0,
            themePrimaryHex: themeManager.selectedTheme.primaryHex,
            themeAccentHex: themeManager.selectedTheme.accentHex,
            updatedAt: .now
        )
        SharedDataProvider.write(data)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
