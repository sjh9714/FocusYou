import Foundation

// MARK: - 뽀모도로 엔진
// focus/shortBreak/longBreak 페이즈를 순차 실행하기 위한 상태 머신

struct PomodoroConfiguration: Equatable, Sendable {
    var focusMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int
    var cycles: Int

    static let `default` = PomodoroConfiguration(
        focusMinutes: Constants.Timer.pomodoroFocusDefaultMinutes,
        shortBreakMinutes: Constants.Timer.pomodoroShortBreakDefaultMinutes,
        longBreakMinutes: Constants.Timer.pomodoroLongBreakDefaultMinutes,
        cycles: Constants.Timer.pomodoroCyclesDefault
    )

    var plannedFocusDuration: TimeInterval {
        TimeInterval(focusMinutes * cycles * 60)
    }
}

@MainActor
@Observable
final class PomodoroEngine {
    enum PhaseType: String, Equatable, Sendable {
        case focus
        case shortBreak
        case longBreak

        var displayName: String {
            switch self {
            case .focus:
                return "집중"
            case .shortBreak:
                return "짧은 휴식"
            case .longBreak:
                return "긴 휴식"
            }
        }
    }

    struct Phase: Equatable, Sendable {
        let type: PhaseType
        let duration: TimeInterval
        let cycleIndex: Int
    }

    private(set) var configuration: PomodoroConfiguration = .default
    private(set) var phases: [Phase] = []
    private(set) var currentPhaseIndex = 0

    var currentPhase: Phase? {
        guard phases.indices.contains(currentPhaseIndex) else { return nil }
        return phases[currentPhaseIndex]
    }

    var totalPhases: Int { phases.count }

    func start(configuration: PomodoroConfiguration) -> Phase? {
        self.configuration = configuration
        phases = Self.buildPhases(configuration: configuration)
        currentPhaseIndex = 0
        return currentPhase
    }

    func advancePhase() -> Phase? {
        guard currentPhaseIndex + 1 < phases.count else { return nil }
        currentPhaseIndex += 1
        return currentPhase
    }

    func reset() {
        phases = []
        currentPhaseIndex = 0
    }

    static func buildPhases(configuration: PomodoroConfiguration) -> [Phase] {
        guard configuration.cycles > 0 else { return [] }

        var built: [Phase] = []
        for cycle in 1...configuration.cycles {
            built.append(
                Phase(
                    type: .focus,
                    duration: TimeInterval(configuration.focusMinutes * 60),
                    cycleIndex: cycle
                )
            )

            let breakType: PhaseType = (cycle == configuration.cycles) ? .longBreak : .shortBreak
            let breakMinutes = (breakType == .longBreak) ? configuration.longBreakMinutes : configuration.shortBreakMinutes
            built.append(
                Phase(
                    type: breakType,
                    duration: TimeInterval(breakMinutes * 60),
                    cycleIndex: cycle
                )
            )
        }

        return built
    }
}
