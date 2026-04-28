import Foundation
import SwiftData

extension AppState {
    /// 회고 이모지 저장 (완료 화면에서 호출)
    func saveRetrospectEmoji(_ emoji: String) {
        completedSession?.retrospectEmoji = emoji
        logger.info("회고 이모지 저장: \(emoji)")
    }

    /// 회고 전체 데이터 저장 (Level 2-3용)
    func saveRetrospectFull(emoji: String?, text: String?, rating: Int?) {
        completedSession?.retrospectEmoji = emoji
        completedSession?.retrospectText = text
        completedSession?.retrospectRating = rating
        logger.info("회고 저장 완료")
    }

    // MARK: - 마일스톤 체크 (v1.5)

    func checkMilestones(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<FocusSession>()
        let allSessions: [FocusSession]
        do {
            allSessions = try modelContext.fetch(descriptor)
        } catch {
            logger.error("마일스톤 체크 실패 — 세션 fetch 에러: \(error.localizedDescription)")
            return
        }

        let evaluation = progressEvaluator.evaluate(
            allSessions: allSessions,
            completedSession: completedSession,
            previousLevel: previousLevel
        )

        if !evaluation.newMilestones.isEmpty {
            MilestoneDetector.saveBadges(evaluation.newMilestones, modelContext: modelContext)
            pendingMilestone = evaluation.pendingMilestone
        }

        lastCompletedXPEarned = evaluation.xpEarned
        previousLevel = evaluation.nextPreviousLevel
        if let pendingLevelUp = evaluation.pendingLevelUp {
            self.pendingLevelUp = pendingLevelUp
            logger.info("레벨업 감지: \(pendingLevelUp)")
        }
    }

    /// 위젯에 현재 상태 전달 (세션 시작/종료/타이머 변경 시 호출)
    func updateSharedData() {
        let themeManager = ThemeManager.shared
        let remaining: Int
        let total: Int

        switch timerMode {
        case .free:
            remaining = Int(timer.remainingTime)
            total = Int(timer.totalDuration)
        case .pomodoro:
            remaining = Int(timer.remainingTime)
            total = Int(timer.totalDuration)
        case .flowmodoro:
            remaining = Int(timer.remainingTime)
            total = Int(timer.totalDuration)
        }

        let data = SharedFocusData(
            isFocusing: focusState == .focusing,
            timerMode: timerMode.rawValue,
            remainingSeconds: remaining,
            totalSeconds: total,
            currentStreak: lastCompletedStreakInfo?.current ?? 0,
            longestStreak: lastCompletedStreakInfo?.longest ?? 0,
            todayFocusMinutes: 0,
            todaySessionCount: 0,
            themePrimaryHex: themeManager.selectedTheme.primaryHex,
            themeAccentHex: themeManager.selectedTheme.accentHex,
            updatedAt: .now
        )
        sharedDataPublisher.publish(data)
    }
}
