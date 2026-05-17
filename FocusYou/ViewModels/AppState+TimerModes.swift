import Foundation
import SwiftData

extension AppState {
    func handleTimerComplete() async {
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

    func handlePomodoroPhaseCompletion() async {
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
                    await FocusModeController.shared.deactivateDND()
                    focusState = .idle
                    return
                } else {
                    presentError(
                        String(localized: "error_break_deactivation_failed \(phaseTransitionError.localizedDescription)"),
                        canRetryDeactivation: true
                    )
                    currentSession?.cancel(actualDuration: completedFocusSeconds)
                    currentSession = nil
                    timer.reset()
                    endPomodoroIfNeeded()
                    await FocusModeController.shared.deactivateDND()
                    focusState = .idle
                    return
                }
            }

            currentPomodoroPhase = nextPhase
            pomodoroCycleProgressText = String(localized: "pomodoro_cycle_progress \(nextPhase.cycleIndex) \(pomodoroEngine.configuration.cycles)")

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

    /// 사용자가 "집중 완료"를 누를 때 호출 — 집중 종료 → 자동 휴식 전환
    func finishFlowmodoroFocus(modelContext: ModelContext) async {
        guard timerMode == .flowmodoro,
              focusState == .focusing || focusState == .paused else { return }

        let focusElapsed = timer.elapsedTime
        logger.info("플로우모도로 집중 완료: \(Int(focusElapsed))초")
        timer.stop()

        let breakDuration = flowmodoroEngine.finishFocusAndStartBreak(elapsed: focusElapsed)
        currentFlowmodoroPhase = .rest

        await safelyDeactivateBlocking(
            shouldNotify: false,
            fallbackBlockingState: true
        ) { String(localized: "error_flowmodoro_break_deactivation_failed \($0)") }

        timer.reset()
        timer.start(duration: debugScaledDuration(breakDuration))
        focusState = .focusing
        await notificationService.sendPomodoroPhaseStarted(
            phaseTitle: String(localized: "flowmodoro_rest_phase"),
            cycleText: String(localized: "flowmodoro_rest_seconds \(Int(breakDuration))")
        )
    }

    func handleFlowmodoroCompletion() async {
        if currentFlowmodoroPhase == .rest {
            logger.info("플로우모도로 휴식 완료 → 세션 종료 처리")
            flowmodoroEngine.completeBreak()
            await finalizeSessionAfterCompletion(
                notificationDuration: flowmodoroEngine.focusDuration,
                actualDuration: Int(flowmodoroEngine.focusDuration)
            )
        } else {
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

    func applyBlockingForPomodoroPhase(_ phaseType: PomodoroEngine.PhaseType) async throws {
        let hasBlockingTargets = PersistedBlocklistMode(storedValue: sessionBlocklistMode).hasBlockingTargets(
            domains: sessionBlockedDomains,
            appBundleIds: sessionBlockedAppBundleIds
        )

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

    func endPomodoroIfNeeded() {
        if timerMode == .pomodoro {
            pomodoroEngine.reset()
        }
        timerMode = .free
        currentPomodoroPhase = nil
        pomodoroCycleProgressText = ""
        accumulatedPomodoroFocusDuration = 0
        sessionBlockedDomains = []
        sessionBlockedAppBundleIds = []
        sessionBlocklistMode = "blocklist"
    }

    func endFlowmodoroIfNeeded() {
        if timerMode == .flowmodoro {
            flowmodoroEngine.reset()
            currentFlowmodoroPhase = nil
        }
    }

    func debugScaledDuration(_ seconds: TimeInterval) -> TimeInterval {
        timingCalculator.debugScaledDuration(seconds)
    }
}
