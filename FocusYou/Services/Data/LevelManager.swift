import Foundation
import os

// MARK: - XP / 레벨 시스템 (v1.x)
// 기존 FocusSession 데이터로부터 XP를 계산하고 레벨을 결정
// GrowthManager 패턴: 순수 계산 기반, 새 SwiftData 모델 불필요

@MainActor
enum LevelManager {
    private static let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "LevelManager"
    )

    /// XP 계산 결과
    struct XPInfo: Equatable, Sendable {
        let totalXP: Int
        let level: Int
        /// 현재 레벨 시작점 이후 누적 XP
        let currentLevelXP: Int
        /// 현재 레벨에서 다음 레벨까지 필요한 XP 폭
        let nextLevelXP: Int
        /// 현재 레벨 내 진행률 (0.0 ~ 1.0)
        let progressInLevel: Double
    }

    // MARK: - 세션 XP 계산

    /// 세션 하나의 XP 계산
    /// - 집중 분 × 1 XP
    /// - 완료 시 +20%
    /// - 스트릭 보너스: 일당 +5% (최대 +50%)
    static func xpForSession(
        focusMinutes: Double,
        wasCompleted: Bool,
        currentStreakDays: Int
    ) -> Int {
        guard focusMinutes > 0 else { return 0 }

        var xp = focusMinutes * Constants.XP.xpPerMinute

        if wasCompleted {
            xp *= (1.0 + Constants.XP.completionBonusMultiplier)
        }

        let streakBonus = min(
            Double(currentStreakDays) * Constants.XP.streakBonusPerDay,
            Constants.XP.streakBonusCap
        )
        xp *= (1.0 + streakBonus)

        return Int(xp.rounded())
    }

    // MARK: - 전체 XP 계산

    /// 전체 세션 배열에서 총 XP 계산
    /// focus 세션만 카운트, 현재 스트릭 기반 보너스 적용
    static func totalXP(from sessions: [FocusSession]) -> Int {
        let focusSessions = sessions.filter { $0.sessionType == "focus" }
        let currentStreak = StreakCalculator.calculate(from: sessions).current

        var total = 0
        for session in focusSessions {
            let minutes = Double(session.actualDuration) / 60.0
            total += xpForSession(
                focusMinutes: minutes,
                wasCompleted: session.wasCompleted,
                currentStreakDays: session.wasCompleted ? currentStreak : 0
            )
        }
        return total
    }

    // MARK: - 레벨 계산

    /// 총 XP로부터 레벨 결정
    /// Level N threshold = N × (N-1) × 25
    /// L1=0, L2=50, L3=150, L4=300, L5=500, L10=2250
    static func level(fromTotalXP xp: Int) -> Int {
        var level = 1
        while xpThreshold(forLevel: level + 1) <= xp {
            level += 1
        }
        return level
    }

    /// 특정 레벨 도달에 필요한 누적 XP
    static func xpThreshold(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        return level * (level - 1) * Constants.XP.thresholdMultiplier
    }

    // MARK: - 종합 정보

    /// 전체 XP 정보 계산
    static func xpInfo(from sessions: [FocusSession]) -> XPInfo {
        let total = totalXP(from: sessions)
        let currentLevel = level(fromTotalXP: total)
        let currentThreshold = xpThreshold(forLevel: currentLevel)
        let nextThreshold = xpThreshold(forLevel: currentLevel + 1)
        let xpInLevel = total - currentThreshold
        let xpNeeded = nextThreshold - currentThreshold
        let progress = xpNeeded > 0 ? Double(xpInLevel) / Double(xpNeeded) : 1.0

        return XPInfo(
            totalXP: total,
            level: currentLevel,
            currentLevelXP: xpInLevel,
            nextLevelXP: xpNeeded,
            progressInLevel: min(1.0, progress)
        )
    }
}
