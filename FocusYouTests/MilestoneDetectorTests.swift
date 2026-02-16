import Foundation
import Testing
@testable import Focus_You

// MARK: - MilestoneDetector 테스트 (v1.5)

@Suite("MilestoneDetector")
@MainActor
struct MilestoneDetectorTests {

    // MARK: - 셋업/정리 헬퍼

    /// 테스트 격리를 위해 achievedIDs 초기화 후 원복
    private func withCleanState(_ body: () -> Void) {
        let backup = UserDefaults.standard.stringArray(forKey: "achievedMilestoneIDs")
        UserDefaults.standard.removeObject(forKey: "achievedMilestoneIDs")
        body()
        if let backup {
            UserDefaults.standard.set(backup, forKey: "achievedMilestoneIDs")
        } else {
            UserDefaults.standard.removeObject(forKey: "achievedMilestoneIDs")
        }
    }

    // MARK: - Milestone 상수

    @Test("Milestone.all에 10개 마일스톤 포함")
    func testAllMilestonesCount() {
        #expect(Milestone.all.count == 10)
    }

    @Test("마일스톤 ID 유일성")
    func testMilestoneIDsUnique() {
        let ids = Milestone.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    // MARK: - 스트릭 마일스톤

    @Test("7일 스트릭 마일스톤 달성")
    func testStreak7() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 7,
                totalHours: 0,
                totalSessions: 0
            )
            #expect(result.contains(where: { $0.id == "streak_7" }))
        }
    }

    @Test("30일 스트릭: streak_7 + streak_30 동시 달성")
    func testStreak30() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 30,
                totalHours: 0,
                totalSessions: 0
            )
            #expect(result.contains(where: { $0.id == "streak_7" }))
            #expect(result.contains(where: { $0.id == "streak_30" }))
        }
    }

    @Test("100일 스트릭")
    func testStreak100() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 100,
                totalHours: 0,
                totalSessions: 0
            )
            #expect(result.contains(where: { $0.id == "streak_100" }))
        }
    }

    @Test("365일 스트릭: 4개 스트릭 마일스톤 전부 달성")
    func testStreak365() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 365,
                totalHours: 0,
                totalSessions: 0
            )
            let streakIDs = result.filter { $0.id.hasPrefix("streak_") }.map(\.id)
            #expect(streakIDs.count == 4)
        }
    }

    @Test("스트릭 6일: 마일스톤 미달")
    func testStreakBelowThreshold() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 6,
                totalHours: 0,
                totalSessions: 0
            )
            #expect(result.isEmpty)
        }
    }

    // MARK: - 누적 시간 마일스톤

    @Test("50시간 마일스톤")
    func testHours50() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 0,
                totalHours: 50,
                totalSessions: 0
            )
            #expect(result.contains(where: { $0.id == "hours_50" }))
        }
    }

    @Test("100시간 마일스톤: hours_50 + hours_100 동시")
    func testHours100() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 0,
                totalHours: 100,
                totalSessions: 0
            )
            #expect(result.contains(where: { $0.id == "hours_50" }))
            #expect(result.contains(where: { $0.id == "hours_100" }))
        }
    }

    @Test("500시간 마일스톤: 3개 시간 마일스톤 전부")
    func testHours500() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 0,
                totalHours: 500,
                totalSessions: 0
            )
            let hourIDs = result.filter { $0.id.hasPrefix("hours_") }.map(\.id)
            #expect(hourIDs.count == 3)
        }
    }

    @Test("49시간: 마일스톤 미달")
    func testHoursBelowThreshold() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 0,
                totalHours: 49.9,
                totalSessions: 0
            )
            #expect(result.isEmpty)
        }
    }

    // MARK: - 세션 수 마일스톤

    @Test("100회 세션 마일스톤")
    func testSessions100() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 0,
                totalHours: 0,
                totalSessions: 100
            )
            #expect(result.contains(where: { $0.id == "sessions_100" }))
        }
    }

    @Test("500회 세션: sessions_100 + sessions_500")
    func testSessions500() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 0,
                totalHours: 0,
                totalSessions: 500
            )
            #expect(result.contains(where: { $0.id == "sessions_100" }))
            #expect(result.contains(where: { $0.id == "sessions_500" }))
        }
    }

    @Test("1000회 세션: 3개 세션 마일스톤 전부")
    func testSessions1000() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 0,
                totalHours: 0,
                totalSessions: 1000
            )
            let sessionIDs = result.filter { $0.id.hasPrefix("sessions_") }.map(\.id)
            #expect(sessionIDs.count == 3)
        }
    }

    @Test("99회 세션: 마일스톤 미달")
    func testSessionsBelowThreshold() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 0,
                totalHours: 0,
                totalSessions: 99
            )
            #expect(result.isEmpty)
        }
    }

    // MARK: - 중복 방지

    @Test("이미 달성된 마일스톤은 재반환하지 않음")
    func testNoDuplicateAchievements() {
        withCleanState {
            // 첫 번째 호출: streak_7 달성
            let first = MilestoneDetector.checkMilestones(
                streakDays: 7,
                totalHours: 0,
                totalSessions: 0
            )
            #expect(first.contains(where: { $0.id == "streak_7" }))

            // 두 번째 호출: streak_7은 이미 달성되어 반환 안 됨
            let second = MilestoneDetector.checkMilestones(
                streakDays: 7,
                totalHours: 0,
                totalSessions: 0
            )
            #expect(!second.contains(where: { $0.id == "streak_7" }))
        }
    }

    // MARK: - 복합 조건

    @Test("0 값: 마일스톤 없음")
    func testZeroValues() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 0,
                totalHours: 0,
                totalSessions: 0
            )
            #expect(result.isEmpty)
        }
    }

    @Test("복합 달성: 스트릭 + 시간 + 세션 동시")
    func testMultipleCategories() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 7,
                totalHours: 50,
                totalSessions: 100
            )
            #expect(result.contains(where: { $0.id == "streak_7" }))
            #expect(result.contains(where: { $0.id == "hours_50" }))
            #expect(result.contains(where: { $0.id == "sessions_100" }))
            #expect(result.count == 3)
        }
    }

    @Test("모든 마일스톤 동시 달성 (최대치)")
    func testAllMilestonesAtOnce() {
        withCleanState {
            let result = MilestoneDetector.checkMilestones(
                streakDays: 365,
                totalHours: 500,
                totalSessions: 1000
            )
            #expect(result.count == 10)
        }
    }

    // MARK: - achievedIDs 저장

    @Test("달성 후 achievedIDs에 저장됨")
    func testAchievedIDsPersisted() {
        withCleanState {
            _ = MilestoneDetector.checkMilestones(
                streakDays: 7,
                totalHours: 0,
                totalSessions: 0
            )
            #expect(MilestoneDetector.achievedIDs.contains("streak_7"))
        }
    }
}
