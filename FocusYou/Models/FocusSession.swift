import Foundation
import SwiftData

// MARK: - 집중 세션 기록 모델
// 모든 타이머 모드(free, pomodoro, flowmodoro)에서 공통으로 사용

@Model
final class FocusSession {
    /// 타이머 모드 ("free", "pomodoro", "flowmodoro")
    var timerMode: String

    /// 사용한 프로필 이름
    var profileName: String?

    /// 세션 시작 시각
    var startedAt: Date

    /// 세션 종료 시각
    var endedAt: Date?

    /// 설정한 집중 시간 (초)
    var plannedDuration: Int?

    /// 실제 집중 시간 (초)
    var actualDuration: Int

    /// 오버플로우 시간 (초, v0.3+)
    var overflowDuration: Int

    /// 세션 종류 ("focus", "break", "longBreak")
    var sessionType: String

    /// 정상 완료 여부
    var wasCompleted: Bool

    // MARK: - v1.x 확장 필드 (nullable)

    /// 의도 입력 텍스트
    var intention: String?

    /// 회고 이모지
    var retrospectEmoji: String?

    /// 회고 텍스트
    var retrospectText: String?

    /// 회고 만족도 (1~5)
    var retrospectRating: Int?

    init(
        timerMode: String = "free",
        plannedDuration: Int? = nil
    ) {
        self.timerMode = timerMode
        self.plannedDuration = plannedDuration
        self.startedAt = .now
        self.actualDuration = 0
        self.overflowDuration = 0
        self.sessionType = "focus"
        self.wasCompleted = false
    }

    /// 세션 완료 처리
    func complete(actualDuration: Int) {
        self.endedAt = .now
        self.actualDuration = actualDuration
        self.wasCompleted = true
    }

    /// 세션 취소 처리
    func cancel(actualDuration: Int) {
        self.endedAt = .now
        self.actualDuration = actualDuration
        self.wasCompleted = false
    }
}
