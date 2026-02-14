import XCTest
@testable import Focus_You

@MainActor
final class FlowmodoroEngineTests: XCTestCase {
    func testInitialStateIsIdle() {
        let engine = FlowmodoroEngine()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.focusDuration, 0)
        XCTAssertEqual(engine.breakDuration, 0)
    }

    func testStartFocusTransitionsToFocusState() {
        let engine = FlowmodoroEngine()
        engine.startFocus()
        XCTAssertEqual(engine.state, .focus)
    }

    func testFinishFocusCalculatesBreakAsOneFifth() {
        let engine = FlowmodoroEngine()
        engine.startFocus()

        let breakDuration = engine.finishFocusAndStartBreak(elapsed: 300) // 5분 집중
        XCTAssertEqual(breakDuration, 60, accuracy: 0.01) // 1분 휴식
        XCTAssertEqual(engine.state, .rest)
        XCTAssertEqual(engine.focusDuration, 300)
        XCTAssertEqual(engine.breakDuration, 60, accuracy: 0.01)
    }

    func testFinishFocusMinimumBreakIsOneSecond() {
        let engine = FlowmodoroEngine()
        engine.startFocus()

        let breakDuration = engine.finishFocusAndStartBreak(elapsed: 1) // 1초 집중
        XCTAssertEqual(breakDuration, 1) // 최소 1초
    }

    func testFinishFocusIgnoredWhenNotInFocusState() {
        let engine = FlowmodoroEngine()
        let result = engine.finishFocusAndStartBreak(elapsed: 300)
        XCTAssertEqual(result, 0)
        XCTAssertEqual(engine.state, .idle)
    }

    func testCompleteBreakTransitionsToCompleted() {
        let engine = FlowmodoroEngine()
        engine.startFocus()
        engine.finishFocusAndStartBreak(elapsed: 600)
        engine.completeBreak()
        XCTAssertEqual(engine.state, .completed)
    }

    func testCompleteBreakIgnoredWhenNotInRestState() {
        let engine = FlowmodoroEngine()
        engine.startFocus()
        engine.completeBreak() // focus 상태에서 호출 → 무시
        XCTAssertEqual(engine.state, .focus)
    }

    func testResetClearsAllState() {
        let engine = FlowmodoroEngine()
        engine.startFocus()
        engine.finishFocusAndStartBreak(elapsed: 1200)
        engine.reset()

        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.focusDuration, 0)
        XCTAssertEqual(engine.breakDuration, 0)
    }

    func testFullLifecycle() {
        let engine = FlowmodoroEngine()

        // idle → focus
        engine.startFocus()
        XCTAssertEqual(engine.state, .focus)

        // focus → rest (25분 집중 → 5분 휴식)
        let breakDuration = engine.finishFocusAndStartBreak(elapsed: 1500)
        XCTAssertEqual(engine.state, .rest)
        XCTAssertEqual(breakDuration, 300, accuracy: 0.01)
        XCTAssertEqual(engine.focusDuration, 1500)

        // rest → completed
        engine.completeBreak()
        XCTAssertEqual(engine.state, .completed)
    }

    func testCustomBreakRatio() {
        let engine = FlowmodoroEngine(breakRatio: 0.5) // 1/2 비율

        engine.startFocus()
        let breakDuration = engine.finishFocusAndStartBreak(elapsed: 600)
        XCTAssertEqual(breakDuration, 300, accuracy: 0.01) // 600 * 0.5
    }

    func testDefaultBreakRatioMatchesConstant() {
        let engine = FlowmodoroEngine()
        engine.startFocus()
        let breakDuration = engine.finishFocusAndStartBreak(elapsed: 1000)
        let expected = 1000 * Constants.Timer.flowmodoroBreakRatio
        XCTAssertEqual(breakDuration, expected, accuracy: 0.01)
    }
}
