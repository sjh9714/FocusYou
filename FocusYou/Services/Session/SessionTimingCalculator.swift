import Foundation

struct SessionTimingCalculator {
    func plannedDuration(
        mode: AppState.TimerMode,
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

    func secondsUntilScheduleEnd(
        endMinuteOfDay: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TimeInterval {
        let currentSecond = calendar.component(.hour, from: now) * 3600
            + calendar.component(.minute, from: now) * 60
            + calendar.component(.second, from: now)
        let endSecond = endMinuteOfDay * 60

        let remaining: Int
        if currentSecond < endSecond {
            remaining = endSecond - currentSecond
        } else {
            remaining = (24 * 3600 - currentSecond) + endSecond
        }
        return TimeInterval(max(remaining, 0))
    }

    func pomodoroBreakDuration(configuration: PomodoroConfiguration) -> TimeInterval {
        guard configuration.cycles > 0 else { return 0 }

        let shortBreakCount = max(configuration.cycles - 1, 0)
        let totalBreakMinutes = (shortBreakCount * configuration.shortBreakMinutes)
            + configuration.longBreakMinutes
        return TimeInterval(totalBreakMinutes * 60)
    }

    #if DEBUG
    func debugScaledDuration(
        _ seconds: TimeInterval,
        defaults: UserDefaults = .standard
    ) -> TimeInterval {
        guard defaults.bool(forKey: Constants.Settings.debugFastTimerEnabledKey) else {
            return seconds
        }

        let configuredValue = defaults.object(
            forKey: Constants.Settings.debugSecondsPerMinuteKey
        ) == nil
            ? Constants.Settings.debugSecondsPerMinuteDefault
            : defaults.double(forKey: Constants.Settings.debugSecondsPerMinuteKey)
        let normalizedSecondsPerMinute = max(1, configuredValue)
        return (seconds / 60.0) * normalizedSecondsPerMinute
    }
    #else
    func debugScaledDuration(
        _ seconds: TimeInterval,
        defaults: UserDefaults = .standard
    ) -> TimeInterval {
        seconds
    }
    #endif
}
