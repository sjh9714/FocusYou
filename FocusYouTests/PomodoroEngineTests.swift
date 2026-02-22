import XCTest
@testable import Focus_You

@MainActor
final class PomodoroEngineTests: XCTestCase {
    func testBuildPhasesCreatesExpectedOrderForFourCycles() {
        let configuration = PomodoroConfiguration(
            focusMinutes: 25,
            shortBreakMinutes: 5,
            longBreakMinutes: 15,
            cycles: 4
        )

        let phases = PomodoroEngine.buildPhases(configuration: configuration)

        // 4 cycles: focus, shortBreak, focus, shortBreak, focus, shortBreak, focus, longBreak
        XCTAssertEqual(phases.count, 8)
        XCTAssertEqual(phases[0].type, .focus)
        XCTAssertEqual(phases[0].duration, 25 * 60)
        XCTAssertEqual(phases[1].type, .shortBreak)
        XCTAssertEqual(phases[1].duration, 5 * 60)
        XCTAssertEqual(phases[3].type, .shortBreak)
        XCTAssertEqual(phases[5].type, .shortBreak)
        XCTAssertEqual(phases[6].type, .focus)
        XCTAssertEqual(phases[6].cycleIndex, 4)
        XCTAssertEqual(phases[7].type, .longBreak)
        XCTAssertEqual(phases[7].duration, 15 * 60)
        XCTAssertEqual(phases[7].cycleIndex, 4)
    }

    func testAdvancePhaseMovesUntilEndThenReturnsNil() {
        let engine = PomodoroEngine()
        let configuration = PomodoroConfiguration(
            focusMinutes: 20,
            shortBreakMinutes: 5,
            longBreakMinutes: 10,
            cycles: 2
        )

        let first = engine.start(configuration: configuration)
        XCTAssertEqual(first?.type, .focus)
        XCTAssertEqual(first?.duration, 20 * 60)
        XCTAssertEqual(first?.cycleIndex, 1)

        let second = engine.advancePhase()
        XCTAssertEqual(second?.type, .shortBreak)
        XCTAssertEqual(second?.duration, 5 * 60)
        XCTAssertEqual(second?.cycleIndex, 1)

        let third = engine.advancePhase()
        XCTAssertEqual(third?.type, .focus)
        XCTAssertEqual(third?.duration, 20 * 60)
        XCTAssertEqual(third?.cycleIndex, 2)

        // 마지막 사이클 후 긴 휴식
        let fourth = engine.advancePhase()
        XCTAssertEqual(fourth?.type, .longBreak)
        XCTAssertEqual(fourth?.duration, 10 * 60)
        XCTAssertEqual(fourth?.cycleIndex, 2)

        // 긴 휴식 이후 nil
        XCTAssertNil(engine.advancePhase())
    }

    func testBuildPhasesUsesConfiguredDurationsForEachCycle() {
        let configuration = PomodoroConfiguration(
            focusMinutes: 30,
            shortBreakMinutes: 7,
            longBreakMinutes: 20,
            cycles: 3
        )

        let phases = PomodoroEngine.buildPhases(configuration: configuration)

        // 3 cycles: focus, shortBreak, focus, shortBreak, focus, longBreak
        XCTAssertEqual(phases.count, 6)
        XCTAssertEqual(phases.map(\.type), [.focus, .shortBreak, .focus, .shortBreak, .focus, .longBreak])
        XCTAssertEqual(phases.map(\.duration), [1800, 420, 1800, 420, 1800, 1200])
        XCTAssertEqual(phases.map(\.cycleIndex), [1, 1, 2, 2, 3, 3])
    }

    func testBuildPhasesSingleCycleHasOnlyFocusAndLongBreak() {
        let configuration = PomodoroConfiguration(
            focusMinutes: 40,
            shortBreakMinutes: 10,
            longBreakMinutes: 25,
            cycles: 1
        )

        let phases = PomodoroEngine.buildPhases(configuration: configuration)

        // 1 cycle: focus + longBreak
        XCTAssertEqual(phases.count, 2)
        XCTAssertEqual(phases.map(\.type), [.focus, .longBreak])
        XCTAssertEqual(phases.map(\.duration), [2400, 1500])
        XCTAssertEqual(phases.map(\.cycleIndex), [1, 1])
    }

    func testBuildPhasesMaxCycleMatchesExpectedTimelineAndDurations() {
        let maxCycles = Constants.Timer.pomodoroCyclesRange.upperBound
        let configuration = PomodoroConfiguration(
            focusMinutes: 35,
            shortBreakMinutes: 8,
            longBreakMinutes: 20,
            cycles: maxCycles
        )

        let phases = PomodoroEngine.buildPhases(configuration: configuration)

        // maxCycles개 focus + (maxCycles-1)개 shortBreak + 1개 longBreak
        XCTAssertEqual(phases.count, maxCycles * 2)
        XCTAssertEqual(phases.filter { $0.type == .focus }.count, maxCycles)
        XCTAssertEqual(phases.filter { $0.type == .shortBreak }.count, maxCycles - 1)
        XCTAssertEqual(phases.filter { $0.type == .longBreak }.count, 1)
        XCTAssertEqual(phases.last?.type, .longBreak)
        XCTAssertEqual(phases.last?.cycleIndex, maxCycles)

        let expectedTotalDuration = TimeInterval(
            (configuration.focusMinutes * maxCycles)
                + (configuration.shortBreakMinutes * (maxCycles - 1))
                + configuration.longBreakMinutes
        ) * 60
        let timelineDuration = phases.reduce(0) { $0 + $1.duration }
        XCTAssertEqual(timelineDuration, expectedTotalDuration)
    }

    func testPlannedFocusDurationMatchesFocusMinutesAndCycles() {
        let configuration = PomodoroConfiguration(
            focusMinutes: 40,
            shortBreakMinutes: 10,
            longBreakMinutes: 25,
            cycles: 4
        )

        XCTAssertEqual(configuration.plannedFocusDuration, 40 * 4 * 60)
    }

    func testBuildPhasesReturnsEmptyWhenCyclesIsZeroOrNegative() {
        let zeroCycleConfiguration = PomodoroConfiguration(
            focusMinutes: 25,
            shortBreakMinutes: 5,
            longBreakMinutes: 15,
            cycles: 0
        )
        let negativeCycleConfiguration = PomodoroConfiguration(
            focusMinutes: 25,
            shortBreakMinutes: 5,
            longBreakMinutes: 15,
            cycles: -1
        )

        XCTAssertTrue(PomodoroEngine.buildPhases(configuration: zeroCycleConfiguration).isEmpty)
        XCTAssertTrue(PomodoroEngine.buildPhases(configuration: negativeCycleConfiguration).isEmpty)
    }
}
