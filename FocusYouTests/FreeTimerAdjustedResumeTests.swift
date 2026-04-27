import XCTest
@testable import Focus_You

@MainActor
final class FreeTimerAdjustedResumeTests: XCTestCase {
    private var timer: FreeTimer!

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            timer = FreeTimer()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            timer.reset()
            timer = nil
        }
        try await super.tearDown()
    }

    // MARK: - resumeWithAdjustedRemaining

    func testResumeWithAdjustedRemainingUpdatesState() {
        timer.start(duration: 600)
        timer.pause()
        XCTAssertEqual(timer.state, .paused)

        timer.resumeWithAdjustedRemaining(300)
        XCTAssertEqual(timer.state, .running)
    }

    func testResumeWithAdjustedRemainingUpdatesRemainingTime() {
        timer.start(duration: 600)
        timer.pause()

        timer.resumeWithAdjustedRemaining(120)
        XCTAssertEqual(timer.remainingTime, 120, accuracy: 1.0)
    }

    func testResumeWithAdjustedRemainingPreservesElapsed() {
        timer.start(duration: 600)
        // 약간의 시간 경과 시뮬레이션 (시작 직후이므로 elapsed ≈ 0)
        timer.pause()
        let elapsedBefore = timer.elapsedTime

        timer.resumeWithAdjustedRemaining(300)

        // 경과 시간은 보존되어야 함 (오차 1초 허용)
        XCTAssertEqual(timer.elapsedTime, elapsedBefore, accuracy: 1.0)
    }

    func testResumeWithAdjustedRemainingZeroCompletesImmediately() {
        var completionCalled = false
        timer.onComplete = { completionCalled = true }

        timer.start(duration: 600)
        timer.pause()

        timer.resumeWithAdjustedRemaining(0)
        XCTAssertEqual(timer.state, .completed)
        XCTAssertEqual(timer.remainingTime, 0)
        XCTAssertTrue(completionCalled)
    }

    func testResumeWithAdjustedRemainingIgnoredWhenNotPaused() {
        timer.start(duration: 600)
        // running 상태에서 호출 → 무시
        timer.resumeWithAdjustedRemaining(300)
        // totalDuration은 원래 값(600) 유지
        XCTAssertEqual(timer.totalDuration, 600, accuracy: 1.0)
    }
}
