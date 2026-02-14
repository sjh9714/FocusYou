import AppKit
import SwiftUI
import SwiftData
import os

// MARK: - 전역 앱 상태
// 타이머, 차단, 세션을 통합 관리하는 중앙 상태

@MainActor
@Observable
final class AppState {

    // MARK: - 집중 상태

    enum FocusState {
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
    private(set) var lastCompletedMode: TimerMode = .free
    private(set) var lastCompletedFocusDuration: TimeInterval = 0
    private(set) var lastCompletedPomodoroCycles = 0
    private(set) var lastCompletedPomodoroBreakDuration: TimeInterval = 0
    private(set) var lastCompletedFlowmodoroBreakDuration: TimeInterval = 0
    var lastCompletedStreakInfo: StreakCalculator.StreakInfo?

    /// 현재 세션
    private(set) var currentSession: FocusSession?

    /// 에러 메시지 (alert용)
    var errorMessage: String?
    var showError = false
    var canRetryBlockingDeactivation = false

    /// Private Relay 경고 표시 여부
    var showPrivateRelayWarning = false
    private var privateRelayWarningDismissedThisSession = false

    // MARK: - 타이머

    let timer = FreeTimer()
    private let pomodoroEngine = PomodoroEngine()
    private let flowmodoroEngine = FlowmodoroEngine()
    private(set) var currentFlowmodoroPhase: FlowmodoroEngine.PhaseType?
    private var accumulatedPomodoroFocusDuration: TimeInterval = 0
    private var sessionBlockedDomains: [String] = []
    private var sessionBlockedAppBundleIds: [String] = []

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
            return "\(lastCompletedFocusDuration.formattedAsReadable) 집중 · \(lastCompletedPomodoroCycles)사이클 완료"
        case .flowmodoro:
            return "\(lastCompletedFocusDuration.formattedAsReadable) 플로우 집중했습니다"
        case .free:
            return "\(lastCompletedFocusDuration.formattedAsReadable) 집중했습니다"
        }
    }

    var completedDetailText: String? {
        switch lastCompletedMode {
        case .pomodoro:
            return "휴식 \(lastCompletedPomodoroBreakDuration.formattedAsReadable)"
        case .flowmodoro:
            return "자동 휴식 \(lastCompletedFlowmodoroBreakDuration.formattedAsReadable)"
        case .free:
            return nil
        }
    }

    var completedStreakText: String? {
        guard let info = lastCompletedStreakInfo, info.current > 0 else { return nil }
        return "\(info.current)일 연속 집중!"
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
                        "앱 시작 시 차단 복구에 실패했습니다. \(cleanupError.localizedDescription)",
                        canRetryDeactivation: true
                    )
                }
            }
        }
    }

    // MARK: - 집중 세션 시작

    func startFocusSession(
        duration: TimeInterval,
        sites: [BlockedSite],
        apps: [BlockedApp],
        modelContext: ModelContext,
        mode: TimerMode = .free,
        pomodoroConfiguration: PomodoroConfiguration = .default
    ) async {
        guard focusState == .idle else {
            logger.warning("세션 시작 실패: 이미 진행 중")
            return
        }

        logger.info("집중 세션 시작: \(mode.rawValue, privacy: .public), \(Int(duration))초")

        if mode == .pomodoro,
           PomodoroEngine.buildPhases(configuration: pomodoroConfiguration).isEmpty {
            presentError("뽀모도로 설정이 올바르지 않습니다.")
            return
        }

        do {
            // 1. 차단 활성화
            let enabledDomains = sites.filter(\.isEnabled).map(\.domain)
            let effectiveBundleIds = apps.filter(\.isEnabled).map(\.bundleId)

            logger.info("차단 대상: 사이트 \(enabledDomains.count)개, 앱 \(effectiveBundleIds.count)개")

            if enabledDomains.isEmpty && effectiveBundleIds.isEmpty {
                logger.warning("차단 목록이 비어있음 — 차단 없이 타이머만 시작")
            }

            try await blockingCoordinator.activateBlocking(
                domains: enabledDomains,
                appBundleIds: effectiveBundleIds
            )
            isBlockingActive = !enabledDomains.isEmpty || !effectiveBundleIds.isEmpty
            sessionBlockedDomains = enabledDomains
            sessionBlockedAppBundleIds = effectiveBundleIds

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
                pomodoroCycleProgressText = "사이클 \(firstPhase.cycleIndex)/\(pomodoroConfiguration.cycles)"
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

            // 4. 상태 전환
            focusState = .focusing
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
        sites: [BlockedSite],
        apps: [BlockedApp],
        modelContext: ModelContext
    ) async {
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

        await startFocusSession(
            duration: duration,
            sites: sites,
            apps: apps,
            modelContext: modelContext,
            mode: mode,
            pomodoroConfiguration: pomodoroConfig
        )

        currentSession?.profileName = profile.name
    }

    // MARK: - 일시정지 / 재개

    func pauseSession() {
        guard focusState == .focusing else { return }
        timer.pause()
        focusState = .paused
        logger.info("세션 일시정지")
    }

    func resumeSession() {
        guard focusState == .paused else { return }
        timer.resume()
        focusState = .focusing
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

        // 차단 해제
        do {
            try await blockingCoordinator.deactivateBlocking()
            if wasBlockingActive {
                await notificationService.sendBlockingDeactivated()
            }
            isBlockingActive = false
        } catch {
            logger.error("차단 해제 실패: \(error.localizedDescription)")
            isBlockingActive = wasBlockingActive
            presentError(
                "차단 해제에 실패했습니다. \(error.localizedDescription)",
                canRetryDeactivation: true
            )
        }

        // 세션 기록 업데이트
        currentSession?.cancel(actualDuration: elapsed)
        currentSession = nil
        endFlowmodoroIfNeeded()
        endPomodoroIfNeeded()

        focusState = .idle
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
                            """
                            집중 단계 차단 활성화에 실패했고 차단 정리도 실패했습니다. \
                            활성화 오류: \(phaseTransitionError.localizedDescription) \
                            정리 오류: \(cleanupError.localizedDescription)
                            """,
                            canRetryDeactivation: true
                        )
                    } else {
                        presentError(
                            "집중 단계 차단 활성화에 실패해 세션을 종료했습니다. \(phaseTransitionError.localizedDescription)"
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
                        "휴식 단계 차단 해제에 실패했습니다. \(phaseTransitionError.localizedDescription)",
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
            pomodoroCycleProgressText = "사이클 \(nextPhase.cycleIndex)/\(pomodoroEngine.configuration.cycles)"

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

        // 휴식 계산
        let breakDuration = flowmodoroEngine.finishFocusAndStartBreak(elapsed: focusElapsed)
        currentFlowmodoroPhase = .rest

        // 차단 해제
        do {
            try await blockingCoordinator.deactivateBlocking()
            isBlockingActive = false
        } catch {
            logger.error("플로우모도로 휴식 전환 차단 해제 실패: \(error.localizedDescription)")
            isBlockingActive = false
        }

        // 휴식 카운트다운 시작
        timer.reset()
        timer.start(duration: debugScaledDuration(breakDuration))
        focusState = .focusing
        await notificationService.sendPomodoroPhaseStarted(
            phaseTitle: "플로우 휴식",
            cycleText: "\(Int(breakDuration))초"
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

        // 1. 완료 알림
        await notificationService.sendTimerCompleted(
            duration: notificationDuration
        )

        // 2. 차단 해제
        do {
            try await blockingCoordinator.deactivateBlocking()
            if wasBlockingActive {
                await notificationService.sendBlockingDeactivated()
            }
            isBlockingActive = false
        } catch {
            logger.error("타이머 완료 후 차단 해제 실패: \(error.localizedDescription)")
            isBlockingActive = wasBlockingActive
            presentError(
                "타이머 완료 후 차단 해제에 실패했습니다. \(error.localizedDescription)",
                canRetryDeactivation: true
            )
        }

        // 3. 세션 기록
        currentSession?.complete(actualDuration: actualDuration)
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

        // 4. 상태 전환
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
                appBundleIds: sessionBlockedAppBundleIds
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
        lastCompletedMode = .free
        lastCompletedFocusDuration = 0
        lastCompletedPomodoroCycles = 0
        lastCompletedPomodoroBreakDuration = 0
        lastCompletedFlowmodoroBreakDuration = 0
        lastCompletedStreakInfo = nil
        focusState = .idle
    }

    /// 차단 해제 재시도 (오류 UI의 재시도 버튼에서 호출)
    func retryBlockingDeactivation() async {
        guard canRetryBlockingDeactivation else { return }

        do {
            try await blockingCoordinator.deactivateBlocking()
            if isBlockingActive {
                await notificationService.sendBlockingDeactivated()
            }
            isBlockingActive = false
            dismissError()
        } catch {
            logger.error("차단 해제 재시도 실패: \(error.localizedDescription)")
            isBlockingActive = true
            presentError(
                "차단 해제 재시도에 실패했습니다. \(error.localizedDescription)",
                canRetryDeactivation: true
            )
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
}
