import Foundation
import SwiftData

extension AppState {
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
            let targets = targetResolver.resolve(
                sites: sites,
                apps: apps,
                blocklistMode: blocklistMode
            )

            logger.info("차단 대상: 사이트 \(targets.domains.count)개, 앱 \(targets.appBundleIds.count)개, 모드: \(targets.blocklistMode)")

            if !targets.hasBlockingTargets {
                logger.warning("차단 목록이 비어있음 — 차단 없이 타이머만 시작")
            }

            try await blockingCoordinator.activateBlocking(
                domains: targets.domains,
                appBundleIds: targets.appBundleIds,
                blocklistMode: targets.blocklistMode
            )
            isBlockingActive = targets.hasBlockingTargets
            sessionBlockedDomains = targets.domains
            sessionBlockedAppBundleIds = targets.appBundleIds
            sessionBlocklistMode = targets.blocklistMode

            if isBlockingActive && !targets.domains.isEmpty
               && !privateRelayWarningDismissedThisSession {
                if PrivateRelayDetector.detect() == .enabled {
                    showPrivateRelayWarning = true
                }
            }

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

            let session = FocusSession(
                timerMode: mode.rawValue,
                plannedDuration: timingCalculator.plannedDuration(
                    mode: mode,
                    freeDuration: duration,
                    pomodoroConfiguration: pomodoroConfiguration
                )
            )
            modelContext.insert(session)
            currentSession = session
            currentSession?.intention = intention

            sessionStartedAt = .now
            currentCancelIntensity = cancelIntensity
            currentCancelLockoutMinutes = cancelLockoutMinutes

            focusState = .focusing
            updateSharedData()
            await FocusModeController.shared.activateDND()

            logger.info("집중 세션 시작 완료")

        } catch let error as FocusYouError {
            logger.error("세션 시작 실패: \(error.localizedDescription, privacy: .public)")

            if case .authorizationCancelled = error {
                return
            }

            presentError(error.localizedDescription)
        } catch {
            logger.error("세션 시작 실패 (알 수 없는 에러): \(error.localizedDescription, privacy: .public)")
            presentError(error.localizedDescription)
        }
    }

    func pauseSession() {
        guard focusState == .focusing else { return }
        timer.pause()
        focusState = .paused
        logger.info("세션 일시정지")
    }

    func resumeSession() {
        guard focusState == .paused else { return }

        if let endMinute = scheduleEndMinuteOfDay {
            let newRemaining = timingCalculator.secondsUntilScheduleEnd(endMinuteOfDay: endMinute)
            logger.info("스케줄 실시간 조정 재개: 남은 \(Int(newRemaining))초")
            timer.resumeWithAdjustedRemaining(newRemaining)
        } else {
            timer.resume()
        }

        focusState = .focusing
        logger.info("세션 재개")
    }

    func stopSession(modelContext: ModelContext) async {
        guard focusState == .focusing || focusState == .paused else { return }
        logger.info("세션 중지 (사용자 취소)")
        let wasBlockingActive = isBlockingActive

        let elapsed = Int(sessionElapsedDuration)
        timer.stop()

        await safelyDeactivateBlocking(
            shouldNotify: wasBlockingActive,
            fallbackBlockingState: wasBlockingActive
        ) { String(localized: "error_deactivation_failed \($0)") }

        currentSession?.cancel(actualDuration: elapsed)
        try? currentSession?.modelContext?.save()
        currentSession = nil
        endFlowmodoroIfNeeded()
        endPomodoroIfNeeded()
        resetCancelIntensityState()

        await FocusModeController.shared.deactivateDND()

        activeScheduleName = nil
        scheduleEndMinuteOfDay = nil
        focusState = .idle
        updateSharedData()

        ScheduleManager.shared.checkSchedulesNow()
    }

    func finalizeSessionAfterCompletion(
        notificationDuration: TimeInterval,
        actualDuration: Int
    ) async {
        let wasBlockingActive = isBlockingActive
        let completedMode = timerMode
        let completedPomodoroCycles = pomodoroEngine.configuration.cycles
        let completedPomodoroBreakDuration = timingCalculator.pomodoroBreakDuration(
            configuration: pomodoroEngine.configuration
        )

        await notificationService.sendTimerCompleted(
            duration: notificationDuration
        )

        await safelyDeactivateBlocking(
            shouldNotify: wasBlockingActive,
            fallbackBlockingState: wasBlockingActive
        ) { String(localized: "error_completion_deactivation_failed \($0)") }

        currentSession?.complete(actualDuration: actualDuration)
        try? currentSession?.modelContext?.save()
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

        if LicenseManager.shared.isPro,
           UserDefaults.standard.bool(forKey: Constants.Settings.enableCalendarSyncKey),
           let session = completedSession {
            Task { @MainActor in
                if let eventID = await CalendarSyncService.shared.createEvent(for: session) {
                    session.calendarEventID = eventID
                }
            }
        }

        if let context = completedSession?.modelContext {
            checkMilestones(modelContext: context)
        }

        await FocusModeController.shared.deactivateDND()

        activeScheduleName = nil
        scheduleEndMinuteOfDay = nil
        focusState = .completed
    }

    var sessionElapsedDuration: TimeInterval {
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

    /// 완료 상태에서 유휴로 복귀
    func resetToIdle() {
        timer.reset()
        endFlowmodoroIfNeeded()
        endPomodoroIfNeeded()
        resetCancelIntensityState()
        activeScheduleName = nil
        scheduleEndMinuteOfDay = nil
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
}
