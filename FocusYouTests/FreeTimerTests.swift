import XCTest
@testable import Focus_You

@MainActor
final class FreeTimerTests: XCTestCase {
    private var timer: FreeTimer!

    override func setUp() {
        super.setUp()
        timer = FreeTimer()
    }

    override func tearDown() {
        timer.reset()
        timer = nil
        super.tearDown()
    }

    // MARK: - 초기 상태

    func testInitialStateIsIdle() {
        XCTAssertEqual(timer.state, .idle)
        XCTAssertEqual(timer.remainingTime, 0)
        XCTAssertEqual(timer.totalDuration, 0)
    }

    // MARK: - Start

    func testStartTransitionsToRunning() {
        timer.start(duration: 300)
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.totalDuration, 300)
        XCTAssertEqual(timer.remainingTime, 300)
    }

    func testStartIgnoredWhenNotIdle() {
        timer.start(duration: 300)
        timer.start(duration: 600) // 무시되어야 함
        XCTAssertEqual(timer.totalDuration, 300)
    }

    // MARK: - Pause

    func testPauseFromRunning() {
        timer.start(duration: 300)
        timer.pause()
        XCTAssertEqual(timer.state, .paused)
    }

    func testPauseIgnoredWhenNotRunning() {
        timer.pause()
        XCTAssertEqual(timer.state, .idle)
    }

    // MARK: - Resume

    func testResumeFromPaused() {
        timer.start(duration: 300)
        timer.pause()
        timer.resume()
        XCTAssertEqual(timer.state, .running)
    }

    func testResumeIgnoredWhenNotPaused() {
        timer.start(duration: 300)
        timer.resume() // running 상태에서 무시
        XCTAssertEqual(timer.state, .running)
    }

    // MARK: - Stop

    func testStopFromRunning() {
        timer.start(duration: 300)
        timer.stop()
        XCTAssertEqual(timer.state, .idle)
        XCTAssertEqual(timer.remainingTime, 0)
    }

    func testStopFromPaused() {
        timer.start(duration: 300)
        timer.pause()
        timer.stop()
        XCTAssertEqual(timer.state, .idle)
    }

    // MARK: - Reset

    func testReset() {
        timer.start(duration: 300)
        timer.reset()
        XCTAssertEqual(timer.state, .idle)
        XCTAssertEqual(timer.remainingTime, 0)
        XCTAssertEqual(timer.totalDuration, 0)
    }

    // MARK: - Computed Properties

    func testElapsedTimeCalculation() {
        timer.start(duration: 100)
        // 시작 직후이므로 remainingTime ≈ 100, elapsedTime ≈ 0
        XCTAssertEqual(timer.elapsedTime, timer.totalDuration - timer.remainingTime)
    }

    func testProgressCalculation() {
        timer.start(duration: 100)
        // 시작 직후이므로 progress ≈ 0
        let progress = timer.progress
        XCTAssertGreaterThanOrEqual(progress, 0)
        XCTAssertLessThanOrEqual(progress, 1)
    }

    func testProgressZeroWhenTotalDurationZero() {
        // idle 상태에서 totalDuration == 0
        XCTAssertEqual(timer.progress, 0)
    }
}
