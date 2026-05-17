import Foundation
import SwiftData

// MARK: - 차단 프로필 모델

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

    /// 차단 모드: "blocklist" (기본) 또는 "allowlist"
    var blocklistMode: String?

    /// 취소 강도 레벨 (0=기본, 1=강함, 2=하드코어)
    var cancelIntensity: Int?

    /// 취소 잠금 시간 (분, Level 1에서 사용)
    var cancelLockoutMinutes: Int?

    /// 연결된 스케줄 목록
    @Relationship(deleteRule: .cascade, inverse: \BlockSchedule.profile)
    var schedules: [BlockSchedule]

    var persistedTimerMode: PersistedTimerMode {
        get { PersistedTimerMode(storedValue: timerMode) }
        set { timerMode = newValue.rawValue }
    }

    var persistedBlocklistMode: PersistedBlocklistMode {
        get { PersistedBlocklistMode(storedValue: blocklistMode) }
        set { blocklistMode = newValue.rawValue }
    }

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
        self.blocklistMode = "blocklist"
        self.cancelIntensity = 0
        self.cancelLockoutMinutes = 5
        self.schedules = []
    }

    /// 기본 프로필 생성
    static func createDefault() -> BlockProfile {
        let profile = BlockProfile(name: String(localized: "default_profile_name"))
        profile.isDefault = true
        return profile
    }

    /// 이 프로필을 기본으로 설정 (다른 프로필의 isDefault를 모두 해제)
    func setAsDefault(allProfiles: [BlockProfile]) {
        for profile in allProfiles {
            profile.isDefault = false
        }
        self.isDefault = true
    }
}

enum PersistedTimerMode: String, Sendable {
    case free
    case pomodoro
    case flowmodoro

    init(storedValue: String?) {
        self = storedValue.flatMap(Self.init(rawValue:)) ?? .free
    }
}

enum PersistedBlocklistMode: String, Sendable {
    case blocklist
    case allowlist

    init(storedValue: String?) {
        self = storedValue.flatMap(Self.init(rawValue:)) ?? .blocklist
    }

    func hasBlockingTargets(domains: [String], appBundleIds: [String]) -> Bool {
        switch self {
        case .blocklist:
            return !domains.isEmpty || !appBundleIds.isEmpty
        case .allowlist:
            return true
        }
    }
}
