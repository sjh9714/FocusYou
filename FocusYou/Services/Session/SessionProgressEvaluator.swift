import Foundation

struct SessionProgressEvaluation {
    let newMilestones: [Milestone]
    let pendingMilestone: Milestone?
    let pendingLevelUp: Int?
    let nextPreviousLevel: Int
    let xpEarned: Int
}

@MainActor
struct SessionProgressEvaluator {
    func evaluate(
        allSessions: [FocusSession],
        completedSession: FocusSession?,
        previousLevel: Int
    ) -> SessionProgressEvaluation {
        let completedSessions = allSessions.filter { $0.wasCompleted }
        let totalHours = Double(completedSessions.reduce(0) { $0 + $1.actualDuration }) / 3600.0
        let totalSessions = completedSessions.count
        let streakDays = StreakCalculator.calculate(from: allSessions).current

        let newMilestones = MilestoneDetector.checkMilestones(
            streakDays: streakDays,
            totalHours: totalHours,
            totalSessions: totalSessions
        )

        let xpInfo = LevelManager.xpInfo(from: allSessions)
        let newLevel = xpInfo.level

        let xpEarned: Int
        if let completedSession, completedSession.wasCompleted {
            let focusMinutes = Double(completedSession.actualDuration) / 60.0
            xpEarned = LevelManager.xpForSession(
                focusMinutes: focusMinutes,
                wasCompleted: true,
                currentStreakDays: streakDays
            )
        } else {
            xpEarned = 0
        }

        let pendingLevelUp: Int?
        let nextPreviousLevel: Int
        if previousLevel == 0 {
            pendingLevelUp = nil
            nextPreviousLevel = newLevel
        } else if newLevel > previousLevel {
            pendingLevelUp = newLevel
            nextPreviousLevel = newLevel
        } else {
            pendingLevelUp = nil
            nextPreviousLevel = previousLevel
        }

        return SessionProgressEvaluation(
            newMilestones: newMilestones,
            pendingMilestone: newMilestones.first,
            pendingLevelUp: pendingLevelUp,
            nextPreviousLevel: nextPreviousLevel,
            xpEarned: xpEarned
        )
    }
}
