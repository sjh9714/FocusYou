import Foundation

struct ProfileSessionInput {
    let mode: AppState.TimerMode
    let pomodoroConfiguration: PomodoroConfiguration
    let duration: TimeInterval
    let sites: [BlockedSite]
    let apps: [BlockedApp]
    let blocklistMode: String
    let cancelIntensity: Int
    let cancelLockoutMinutes: Int
}

struct ProfileSessionMapper {
    func makeInput(
        from profile: BlockProfile,
        durationOverride: TimeInterval? = nil
    ) -> ProfileSessionInput {
        let mode: AppState.TimerMode = switch profile.timerMode {
        case "pomodoro": .pomodoro
        case "flowmodoro": .flowmodoro
        default: .free
        }

        let pomodoroConfiguration = PomodoroConfiguration(
            focusMinutes: profile.focusDuration / 60,
            shortBreakMinutes: profile.breakDuration / 60,
            longBreakMinutes: profile.longBreakDuration / 60,
            cycles: profile.pomodoroCount
        )

        let duration: TimeInterval
        if let durationOverride {
            duration = durationOverride
        } else {
            duration = switch mode {
            case .free:
                TimeInterval(profile.focusDuration)
            case .pomodoro:
                TimeInterval(pomodoroConfiguration.focusMinutes * 60)
            case .flowmodoro:
                Constants.Timer.flowmodoroMaxDuration
            }
        }

        return ProfileSessionInput(
            mode: mode,
            pomodoroConfiguration: pomodoroConfiguration,
            duration: duration,
            sites: profile.blockedSites.filter(\.isEnabled),
            apps: profile.blockedApps.filter(\.isEnabled),
            blocklistMode: profile.blocklistMode ?? "blocklist",
            cancelIntensity: profile.cancelIntensity ?? 0,
            cancelLockoutMinutes: profile.cancelLockoutMinutes ?? 5
        )
    }
}
