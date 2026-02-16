import Foundation
import os

// MARK: - 플로우모도로 엔진
// 고정 시간 없이 자유롭게 집중 → 집중 시간의 1/5을 자동 휴식으로 부여

@MainActor
@Observable
final class FlowmodoroEngine {

    // MARK: - 페이즈 타입

    enum PhaseType: String, Equatable, Sendable {
        case focus
        case rest

        var displayName: String {
            switch self {
            case .focus:
                return String(localized: "flowmodoro_phase_focus")
            case .rest:
                return String(localized: "flowmodoro_phase_rest")
            }
        }
    }

    // MARK: - 상태

    enum State: Equatable, Sendable {
        case idle
        case focus
        case rest
        case completed
    }

    // MARK: - Properties

    private(set) var state: State = .idle

    /// 실제 집중 시간 (초) — focus 종료 시 확정
    private(set) var focusDuration: TimeInterval = 0

    /// 계산된 휴식 시간 (초) — focusDuration * breakRatio
    private(set) var breakDuration: TimeInterval = 0

    private let breakRatio: Double
    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "FlowmodoroEngine"
    )

    // MARK: - Init

    init(breakRatio: Double = Constants.Timer.flowmodoroBreakRatio) {
        self.breakRatio = breakRatio
    }

    // MARK: - Public Methods

    /// 집중 시작
    func startFocus() {
        state = .focus
        focusDuration = 0
        breakDuration = 0
        logger.info("플로우모도로 집중 시작")
    }

    /// 집중 종료 → 휴식 계산 및 전환
    /// - Parameter elapsed: 실제 집중한 시간 (초)
    /// - Returns: 계산된 휴식 시간 (초)
    @discardableResult
    func finishFocusAndStartBreak(elapsed: TimeInterval) -> TimeInterval {
        guard state == .focus else {
            logger.warning("finishFocusAndStartBreak 호출 시 잘못된 상태: \(String(describing: self.state))")
            return 0
        }

        focusDuration = elapsed
        breakDuration = max(elapsed * breakRatio, 1) // 최소 1초
        state = .rest
        logger.info("집중 \(Int(elapsed))초 → 휴식 \(Int(self.breakDuration))초")
        return breakDuration
    }

    /// 휴식 완료
    func completeBreak() {
        guard state == .rest else {
            logger.warning("completeBreak 호출 시 잘못된 상태: \(String(describing: self.state))")
            return
        }
        state = .completed
        logger.info("플로우모도로 세션 완료")
    }

    /// 초기화
    func reset() {
        state = .idle
        focusDuration = 0
        breakDuration = 0
    }
}
