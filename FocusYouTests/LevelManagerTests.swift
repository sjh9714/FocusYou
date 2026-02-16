import Testing
@testable import Focus_You

// MARK: - LevelManager 테스트 (v1.x)

@Suite("LevelManager")
@MainActor
struct LevelManagerTests {

    // MARK: - XP 계산

    @Test("기본 XP: 집중 25분 = 25 XP (미완료, 스트릭 0)")
    func testXPForSession_basic() {
        let xp = LevelManager.xpForSession(
            focusMinutes: 25,
            wasCompleted: false,
            currentStreakDays: 0
        )
        #expect(xp == 25)
    }

    @Test("완료 보너스: 25분 완료 = 30 XP (+20%)")
    func testXPForSession_completionBonus() {
        let xp = LevelManager.xpForSession(
            focusMinutes: 25,
            wasCompleted: true,
            currentStreakDays: 0
        )
        #expect(xp == 30)
    }

    @Test("스트릭 보너스: 25분 완료 + 5일 스트릭 = +25% → 38 XP")
    func testXPForSession_streakBonus() {
        let xp = LevelManager.xpForSession(
            focusMinutes: 25,
            wasCompleted: true,
            currentStreakDays: 5
        )
        // 25 * 1.2(완료) * 1.25(스트릭5일) = 37.5 → 38
        #expect(xp == 38)
    }

    @Test("스트릭 보너스 캡: 20일 스트릭도 +50%까지만")
    func testXPForSession_streakBonusCap() {
        let xp10 = LevelManager.xpForSession(
            focusMinutes: 100,
            wasCompleted: true,
            currentStreakDays: 10
        )
        let xp20 = LevelManager.xpForSession(
            focusMinutes: 100,
            wasCompleted: true,
            currentStreakDays: 20
        )
        // 둘 다 +50% 캡 적용: 100 * 1.2 * 1.5 = 180
        #expect(xp10 == 180)
        #expect(xp20 == 180)
    }

    @Test("0분 세션 = 0 XP")
    func testXPForSession_zeroMinutes() {
        let xp = LevelManager.xpForSession(
            focusMinutes: 0,
            wasCompleted: true,
            currentStreakDays: 5
        )
        #expect(xp == 0)
    }

    // MARK: - 레벨 계산

    @Test("Level 1 at 0 XP")
    func testLevel_zeroXP() {
        #expect(LevelManager.level(fromTotalXP: 0) == 1)
    }

    @Test("Level 1 at 49 XP (Level 2 threshold = 50)")
    func testLevel_justBelow2() {
        #expect(LevelManager.level(fromTotalXP: 49) == 1)
    }

    @Test("Level 2 at 50 XP")
    func testLevel_exactlyAt2() {
        #expect(LevelManager.level(fromTotalXP: 50) == 2)
    }

    @Test("Level 3 threshold = 150")
    func testLevel_level3() {
        #expect(LevelManager.level(fromTotalXP: 149) == 2)
        #expect(LevelManager.level(fromTotalXP: 150) == 3)
    }

    @Test("Level 5 threshold = 500")
    func testLevel_level5() {
        #expect(LevelManager.level(fromTotalXP: 499) == 4)
        #expect(LevelManager.level(fromTotalXP: 500) == 5)
    }

    @Test("Level 10 threshold = 2250")
    func testLevel_level10() {
        #expect(LevelManager.level(fromTotalXP: 2249) == 9)
        #expect(LevelManager.level(fromTotalXP: 2250) == 10)
    }

    // MARK: - XP threshold 공식

    @Test("XP threshold 공식: N * (N-1) * 25")
    func testXPThreshold_formula() {
        #expect(LevelManager.xpThreshold(forLevel: 1) == 0)
        #expect(LevelManager.xpThreshold(forLevel: 2) == 50)     // 2*1*25
        #expect(LevelManager.xpThreshold(forLevel: 3) == 150)    // 3*2*25
        #expect(LevelManager.xpThreshold(forLevel: 4) == 300)    // 4*3*25
        #expect(LevelManager.xpThreshold(forLevel: 5) == 500)    // 5*4*25
        #expect(LevelManager.xpThreshold(forLevel: 10) == 2250)  // 10*9*25
        #expect(LevelManager.xpThreshold(forLevel: 20) == 9500)  // 20*19*25
    }

    // MARK: - XPInfo 종합

    @Test("XPInfo: 진행률 계산")
    func testXPInfo_progress() {
        // 100 XP → Level 2 (threshold 50), next at 150
        // currentLevelXP = 100 - 50 = 50
        // nextLevelXP = 150 - 50 = 100
        // progress = 50 / 100 = 0.5
        let info = LevelManager.XPInfo(
            totalXP: 100,
            level: LevelManager.level(fromTotalXP: 100),
            currentLevelXP: 50,
            nextLevelXP: 100,
            progressInLevel: 0.5
        )
        #expect(info.level == 2)
        #expect(info.progressInLevel == 0.5)
    }
}
