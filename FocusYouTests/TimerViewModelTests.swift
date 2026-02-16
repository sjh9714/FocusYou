import XCTest
@testable import Focus_You

@MainActor
final class TimerViewModelTests: XCTestCase {
    private var viewModel: TimerViewModel!

    override func setUp() {
        super.setUp()
        viewModel = TimerViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - 기본 상태

    func testDefaultState() {
        XCTAssertEqual(viewModel.selectedMode, .free)
        XCTAssertEqual(viewModel.selectedPreset, 25)
        XCTAssertEqual(viewModel.customMinutes, 25)
        XCTAssertFalse(viewModel.showCancelConfirmation)
    }

    // MARK: - 프리셋 선택

    func testSelectPresetUpdatesBoth() {
        viewModel.selectPreset(50)
        XCTAssertEqual(viewModel.selectedPreset, 50)
        XCTAssertEqual(viewModel.customMinutes, 50)
    }

    func testSelectedDurationMinutesUsesPreset() {
        viewModel.selectPreset(30)
        XCTAssertEqual(viewModel.selectedDurationMinutes, 30)
    }

    func testSelectedDurationMinutesFallsBackToCustom() {
        viewModel.selectedPreset = nil
        viewModel.customMinutes = 42
        XCTAssertEqual(viewModel.selectedDurationMinutes, 42)
    }

    func testSelectedDurationSeconds() {
        viewModel.selectPreset(25)
        XCTAssertEqual(viewModel.selectedDurationSeconds, 1500)
    }

    // MARK: - 커스텀 시간

    func testUpdateCustomMinutesMatchingPreset() {
        viewModel.updateCustomMinutes(25)
        XCTAssertEqual(viewModel.selectedPreset, 25)
    }

    func testUpdateCustomMinutesNonPreset() {
        viewModel.updateCustomMinutes(33)
        XCTAssertNil(viewModel.selectedPreset)
        XCTAssertEqual(viewModel.customMinutes, 33)
    }

    // MARK: - initialDurationSeconds

    func testInitialDurationFreeMode() {
        viewModel.selectedMode = .free
        viewModel.selectPreset(25)
        XCTAssertEqual(viewModel.initialDurationSeconds, 1500)
    }

    func testInitialDurationPomodoroMode() {
        viewModel.selectedMode = .pomodoro
        // 기본 pomodoroConfiguration.focusMinutes = 25
        XCTAssertEqual(viewModel.initialDurationSeconds, 1500)
    }

    func testInitialDurationFlowmodoroMode() {
        viewModel.selectedMode = .flowmodoro
        XCTAssertEqual(viewModel.initialDurationSeconds, Constants.Timer.flowmodoroMaxDuration)
    }

    // MARK: - 모드 선택

    func testSelectMode() {
        viewModel.selectMode(.pomodoro)
        XCTAssertEqual(viewModel.selectedMode, .pomodoro)
    }

    // MARK: - 중지 요청

    func testRequestStopShowsConfirmation() {
        viewModel.requestStop()
        XCTAssertTrue(viewModel.showCancelConfirmation)
    }

    // MARK: - 포맷 텍스트

    func testPomodoroSummaryText() {
        let expected = String(localized: "pomodoro_summary \(25) \(5) \(15) \(4)")
        XCTAssertEqual(viewModel.pomodoroSummaryText, expected)
    }

    // MARK: - TimerMode enum

    func testTimerModeDisplayName() {
        XCTAssertEqual(TimerViewModel.TimerMode.free.displayName, String(localized: "timer_mode_free"))
        XCTAssertEqual(TimerViewModel.TimerMode.pomodoro.displayName, String(localized: "timer_mode_pomodoro"))
        XCTAssertEqual(TimerViewModel.TimerMode.flowmodoro.displayName, String(localized: "timer_mode_flowmodoro"))
    }

    func testTimerModeAppStateConversion() {
        XCTAssertEqual(TimerViewModel.TimerMode.free.appStateMode, .free)
        XCTAssertEqual(TimerViewModel.TimerMode.pomodoro.appStateMode, .pomodoro)
        XCTAssertEqual(TimerViewModel.TimerMode.flowmodoro.appStateMode, .flowmodoro)
    }
}
