import Foundation
import SwiftData

// MARK: - 차단 프로필 모델
// v0.1에서는 기본 프로필 1개만 사용
// v0.5에서 다중 프로필 지원 예정

@Model
final class BlockProfile {
    /// 프로필 이름
    var name: String

    /// SF Symbol 아이콘 이름
    var icon: String

    /// 테마 색상 (hex)
    var color: String

    /// 타이머 모드 ("free", "pomodoro", "flowmodoro")
    var timerMode: String

    /// 집중 시간 (초)
    var focusDuration: Int

    /// 휴식 시간 (초)
    var breakDuration: Int

    /// 긴 휴식 시간 (초)
    var longBreakDuration: Int

    /// 뽀모도로 사이클 수
    var pomodoroCount: Int

    /// 차단 웹사이트 목록
    @Relationship(deleteRule: .cascade, inverse: \BlockedSite.profile)
    var blockedSites: [BlockedSite]

    /// 차단 앱 목록
    @Relationship(deleteRule: .cascade, inverse: \BlockedApp.profile)
    var blockedApps: [BlockedApp]

    /// 기본 프로필 여부
    var isDefault: Bool

    /// 생성 일시
    var createdAt: Date

    init(
        name: String,
        icon: String = "shield.fill",
        color: String = "#E63946"
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.timerMode = "free"
        self.focusDuration = 25 * 60
        self.breakDuration = 5 * 60
        self.longBreakDuration = 15 * 60
        self.pomodoroCount = 4
        self.blockedSites = []
        self.blockedApps = []
        self.isDefault = false
        self.createdAt = .now
    }

    /// 기본 프로필 생성
    static func createDefault() -> BlockProfile {
        let profile = BlockProfile(name: "기본 프로필")
        profile.isDefault = true
        return profile
    }
}
