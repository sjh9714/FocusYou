import Foundation
import SwiftData
import os

// MARK: - 마일스톤 감지 서비스 (v1.5)

struct Milestone: Identifiable, Equatable {
    let id: String
    let title: String
    let emoji: String
    let desc: String

    // MARK: - 스트릭 마일스톤

    static let streak7 = Milestone(
        id: "streak_7", title: String(localized: "milestone_streak_7_title"), emoji: "🔥",
        desc: String(localized: "milestone_streak_7_desc")
    )
    static let streak30 = Milestone(
        id: "streak_30", title: String(localized: "milestone_streak_30_title"), emoji: "💪",
        desc: String(localized: "milestone_streak_30_desc")
    )
    static let streak100 = Milestone(
        id: "streak_100", title: String(localized: "milestone_streak_100_title"), emoji: "⭐",
        desc: String(localized: "milestone_streak_100_desc")
    )
    static let streak365 = Milestone(
        id: "streak_365", title: String(localized: "milestone_streak_365_title"), emoji: "👑",
        desc: String(localized: "milestone_streak_365_desc")
    )

    // MARK: - 누적 시간 마일스톤

    static let hours50 = Milestone(
        id: "hours_50", title: String(localized: "milestone_hours_50_title"), emoji: "⏱️",
        desc: String(localized: "milestone_hours_50_desc")
    )
    static let hours100 = Milestone(
        id: "hours_100", title: String(localized: "milestone_hours_100_title"), emoji: "🎯",
        desc: String(localized: "milestone_hours_100_desc")
    )
    static let hours500 = Milestone(
        id: "hours_500", title: String(localized: "milestone_hours_500_title"), emoji: "🏆",
        desc: String(localized: "milestone_hours_500_desc")
    )

    // MARK: - 세션 수 마일스톤

    static let sessions100 = Milestone(
        id: "sessions_100", title: String(localized: "milestone_sessions_100_title"), emoji: "💯",
        desc: String(localized: "milestone_sessions_100_desc")
    )
    static let sessions500 = Milestone(
        id: "sessions_500", title: String(localized: "milestone_sessions_500_title"), emoji: "🚀",
        desc: String(localized: "milestone_sessions_500_desc")
    )
    static let sessions1000 = Milestone(
        id: "sessions_1000", title: String(localized: "milestone_sessions_1000_title"), emoji: "🌟",
        desc: String(localized: "milestone_sessions_1000_desc")
    )

    static let all: [Milestone] = [
        streak7, streak30, streak100, streak365,
        hours50, hours100, hours500,
        sessions100, sessions500, sessions1000,
    ]
}

@MainActor
enum MilestoneDetector {
    private static let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "MilestoneDetector"
    )

    private static let achievedKey = "achievedMilestoneIDs"

    /// 달성된 마일스톤 ID 세트
    static var achievedIDs: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: achievedKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: achievedKey)
        }
    }

    /// 새로 달성한 마일스톤 반환 (중복 제외)
    static func checkMilestones(
        streakDays: Int,
        totalHours: Double,
        totalSessions: Int
    ) -> [Milestone] {
        var newMilestones: [Milestone] = []
        let achieved = achievedIDs

        // 스트릭 체크
        let streakMilestones: [(Int, Milestone)] = [
            (7, .streak7), (30, .streak30), (100, .streak100), (365, .streak365),
        ]
        for (threshold, milestone) in streakMilestones {
            if streakDays >= threshold && !achieved.contains(milestone.id) {
                newMilestones.append(milestone)
            }
        }

        // 누적 시간 체크
        let hoursMilestones: [(Double, Milestone)] = [
            (50, .hours50), (100, .hours100), (500, .hours500),
        ]
        for (threshold, milestone) in hoursMilestones {
            if totalHours >= threshold && !achieved.contains(milestone.id) {
                newMilestones.append(milestone)
            }
        }

        // 세션 수 체크
        let sessionMilestones: [(Int, Milestone)] = [
            (100, .sessions100), (500, .sessions500), (1000, .sessions1000),
        ]
        for (threshold, milestone) in sessionMilestones {
            if totalSessions >= threshold && !achieved.contains(milestone.id) {
                newMilestones.append(milestone)
            }
        }

        // 새로 달성된 마일스톤 기록
        if !newMilestones.isEmpty {
            var updated = achieved
            for m in newMilestones {
                updated.insert(m.id)
            }
            achievedIDs = updated
            logger.info("새 마일스톤 달성: \(newMilestones.map(\.id))")
        }

        return newMilestones
    }

    /// 배지 저장 (SwiftData)
    static func saveBadges(_ milestones: [Milestone], modelContext: ModelContext) {
        for milestone in milestones {
            let badge = Badge(
                milestoneID: milestone.id,
                title: milestone.title,
                emoji: milestone.emoji,
                desc: milestone.desc
            )
            modelContext.insert(badge)
        }
    }
}
