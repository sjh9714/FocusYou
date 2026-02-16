import Testing
@testable import Focus_You

// MARK: - GrowthManager 테스트 (v1.5)

@Suite("GrowthManager")
@MainActor
struct GrowthManagerTests {

    // MARK: - currentStage

    @Test("0시간 = seed")
    func testStage_zero() {
        #expect(GrowthManager.currentStage(totalHours: 0) == .seed)
    }

    @Test("9.9시간 = seed")
    func testStage_belowSprout() {
        #expect(GrowthManager.currentStage(totalHours: 9.9) == .seed)
    }

    @Test("10시간 = sprout")
    func testStage_exactSprout() {
        #expect(GrowthManager.currentStage(totalHours: 10) == .sprout)
    }

    @Test("49.9시간 = sprout")
    func testStage_belowTree() {
        #expect(GrowthManager.currentStage(totalHours: 49.9) == .sprout)
    }

    @Test("50시간 = tree")
    func testStage_exactTree() {
        #expect(GrowthManager.currentStage(totalHours: 50) == .tree)
    }

    @Test("149.9시간 = tree")
    func testStage_belowForest() {
        #expect(GrowthManager.currentStage(totalHours: 149.9) == .tree)
    }

    @Test("150시간 = forest")
    func testStage_exactForest() {
        #expect(GrowthManager.currentStage(totalHours: 150) == .forest)
    }

    @Test("499.9시간 = forest")
    func testStage_belowGarden() {
        #expect(GrowthManager.currentStage(totalHours: 499.9) == .forest)
    }

    @Test("500시간 = garden")
    func testStage_exactGarden() {
        #expect(GrowthManager.currentStage(totalHours: 500) == .garden)
    }

    @Test("1000시간 = garden (최대)")
    func testStage_beyondGarden() {
        #expect(GrowthManager.currentStage(totalHours: 1000) == .garden)
    }

    // MARK: - progress

    @Test("seed 시작 = 0.0")
    func testProgress_seedStart() {
        let p = GrowthManager.progress(totalHours: 0)
        #expect(p == 0.0)
    }

    @Test("seed 50% = 5시간/10시간")
    func testProgress_seedHalf() {
        let p = GrowthManager.progress(totalHours: 5)
        #expect(abs(p - 0.5) < 0.01)
    }

    @Test("sprout 시작 = 0.0")
    func testProgress_sproutStart() {
        let p = GrowthManager.progress(totalHours: 10)
        #expect(abs(p - 0.0) < 0.01)
    }

    @Test("sprout 50% = 30시간 (10~50 범위)")
    func testProgress_sproutHalf() {
        let p = GrowthManager.progress(totalHours: 30)
        #expect(abs(p - 0.5) < 0.01)
    }

    @Test("garden = 1.0 (최대 단계)")
    func testProgress_garden() {
        #expect(GrowthManager.progress(totalHours: 500) == 1.0)
        #expect(GrowthManager.progress(totalHours: 1000) == 1.0)
    }

    @Test("progress 범위: 0.0~1.0")
    func testProgress_bounds() {
        for hours in stride(from: 0.0, through: 600.0, by: 50.0) {
            let p = GrowthManager.progress(totalHours: hours)
            #expect(p >= 0.0 && p <= 1.0, "hours=\(hours), progress=\(p)")
        }
    }

    // MARK: - hoursToNextStage

    @Test("seed → sprout: 10시간 남음")
    func testNextStage_fromSeed() {
        #expect(GrowthManager.hoursToNextStage(totalHours: 0) == 10)
    }

    @Test("seed 5시간 → sprout까지 5시간")
    func testNextStage_fromSeed5h() {
        #expect(GrowthManager.hoursToNextStage(totalHours: 5) == 5)
    }

    @Test("sprout → tree: 40시간 남음")
    func testNextStage_fromSprout() {
        #expect(GrowthManager.hoursToNextStage(totalHours: 10) == 40)
    }

    @Test("tree → forest: 100시간 남음")
    func testNextStage_fromTree() {
        #expect(GrowthManager.hoursToNextStage(totalHours: 50) == 100)
    }

    @Test("forest → garden: 350시간 남음")
    func testNextStage_fromForest() {
        #expect(GrowthManager.hoursToNextStage(totalHours: 150) == 350)
    }

    @Test("garden: nil (마지막 단계)")
    func testNextStage_fromGarden() {
        #expect(GrowthManager.hoursToNextStage(totalHours: 500) == nil)
        #expect(GrowthManager.hoursToNextStage(totalHours: 1000) == nil)
    }

    // MARK: - GrowthStage enum

    @Test("GrowthStage Comparable")
    func testStageComparable() {
        #expect(GrowthStage.seed < .sprout)
        #expect(GrowthStage.sprout < .tree)
        #expect(GrowthStage.tree < .forest)
        #expect(GrowthStage.forest < .garden)
    }

    @Test("GrowthStage emoji 비어있지 않음")
    func testStageEmoji() {
        for stage in GrowthStage.allCases {
            #expect(!stage.emoji.isEmpty)
        }
    }

    @Test("GrowthStage.allCases = 5개")
    func testStageAllCases() {
        #expect(GrowthStage.allCases.count == 5)
    }

    @Test("thresholdHours 단조 증가")
    func testStageThresholdsMonotonic() {
        let thresholds = GrowthStage.allCases.map(\.thresholdHours)
        for i in 1..<thresholds.count {
            #expect(thresholds[i] > thresholds[i - 1])
        }
    }
}
