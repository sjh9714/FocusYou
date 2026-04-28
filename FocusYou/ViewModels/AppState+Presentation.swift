import Foundation

extension AppState {
    var isPro: Bool { LicenseManager.shared.isPro }

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
}
