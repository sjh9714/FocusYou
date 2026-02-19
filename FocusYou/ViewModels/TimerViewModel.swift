import SwiftUI
import os

// MARK: - 타이머 ViewModel
// 프리셋 선택, 커스텀 시간, 시간 포맷팅 관리

@MainActor
@Observable
final class TimerViewModel {
    enum TimerMode: String, CaseIterable {
        case free
        case pomodoro
        case flowmodoro

        var displayName: String {
            switch self {
            case .free:
                return String(localized: "timer_mode_free")
            case .pomodoro:
                return String(localized: "timer_mode_pomodoro")
            case .flowmodoro:
                return String(localized: "timer_mode_flowmodoro")
            }
        }

        /// TimerViewModel.TimerMode → AppState.TimerMode 변환
        var appStateMode: AppState.TimerMode {
            switch self {
            case .free: return .free
            case .pomodoro: return .pomodoro
            case .flowmodoro: return .flowmodoro
            }
        }
    }

    /// 타이머 모드
    var selectedMode: TimerMode = .free

    /// 선택된 프리셋 (분), nil이면 커스텀
    var selectedPreset: Int? = 25

    /// 커스텀 시간 (분)
    var customMinutes: Double = 25

    /// 뽀모도로 설정
    var pomodoroConfiguration: PomodoroConfiguration = .default

    /// 취소 강도 (0=기본, 1=강함, 2=하드코어)
    var cancelIntensity: Int = 0

    /// 취소 잠금 시간 (분, Level 1에서 사용)
    var cancelLockoutMinutes: Int = 5

    /// 차단 모드 ("blocklist" | "allowlist")
    var blocklistMode: String = "blocklist"

    /// 취소 확인 다이얼로그 표시 여부
    var showCancelConfirmation = false

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "TimerViewModel"
    )

    // MARK: - Computed Properties

    /// 선택된 시간 (분)
    var selectedDurationMinutes: Int {
        selectedPreset ?? Int(customMinutes)
    }

    /// 선택된 시간 (초)
    var selectedDurationSeconds: TimeInterval {
        TimeInterval(selectedDurationMinutes * 60)
    }

    /// 현재 모드에서 시작 시 사용할 첫 세션 시간 (초)
    var initialDurationSeconds: TimeInterval {
        switch selectedMode {
        case .free:
            return selectedDurationSeconds
        case .pomodoro:
            return TimeInterval(pomodoroConfiguration.focusMinutes * 60)
        case .flowmodoro:
            return Constants.Timer.flowmodoroMaxDuration
        }
    }

    var pomodoroSummaryText: String {
        let config = pomodoroConfiguration
        return String(localized: "pomodoro_summary \(config.focusMinutes) \(config.shortBreakMinutes) \(config.longBreakMinutes) \(config.cycles)")
    }

    // MARK: - Methods

    /// 프리셋 선택
    func selectPreset(_ minutes: Int) {
        selectedPreset = minutes
        customMinutes = Double(minutes)
    }

    /// 커스텀 시간 변경 시 프리셋 해제
    func updateCustomMinutes(_ minutes: Double) {
        customMinutes = minutes.rounded()
        // 프리셋과 일치하면 프리셋 선택, 아니면 해제
        if Constants.Timer.presets.contains(Int(customMinutes)) {
            selectedPreset = Int(customMinutes)
        } else {
            selectedPreset = nil
        }
    }

    /// 중지 요청 (확인 다이얼로그 표시)
    func requestStop() {
        showCancelConfirmation = true
    }

    func selectMode(_ mode: TimerMode) {
        selectedMode = mode
    }

    /// 프로필의 타이머 설정을 로드
    func loadFromProfile(_ profile: BlockProfile) {
        selectedMode = TimerMode(rawValue: profile.timerMode) ?? .free
        let focusMinutes = profile.focusDuration / 60
        selectPreset(focusMinutes)
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
}
