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

        var displayName: String {
            switch self {
            case .free:
                return "자유"
            case .pomodoro:
                return "뽀모도로"
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
        }
    }

    var pomodoroSummaryText: String {
        let config = pomodoroConfiguration
        return "집중 \(config.focusMinutes) / 짧휴 \(config.shortBreakMinutes) / 긴휴 \(config.longBreakMinutes) · \(config.cycles)회"
    }

    // MARK: - Methods

    /// 프리셋 선택
    func selectPreset(_ minutes: Int) {
        selectedPreset = minutes
        customMinutes = Double(minutes)
    }

    /// 커스텀 시간 변경 시 프리셋 해제
    func updateCustomMinutes(_ minutes: Double) {
        customMinutes = minutes
        // 프리셋과 일치하면 프리셋 선택, 아니면 해제
        if Constants.Timer.presets.contains(Int(minutes)) {
            selectedPreset = Int(minutes)
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
}
