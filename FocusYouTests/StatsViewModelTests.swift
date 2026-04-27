import XCTest
@testable import Focus_You

@MainActor
final class StatsViewModelTests: XCTestCase {
    private let calendar = Calendar.current
    private var viewModel: StatsViewModel!

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            viewModel = StatsViewModel()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            viewModel = nil
        }
        try await super.tearDown()
    }

    // MARK: - 헬퍼

    /// 특정 날짜에 세션 생성
    private func makeSession(
        daysAgo: Int,
        mode: String = "free",
        completed: Bool = true,
        duration: Int = 1500
    ) -> FocusSession {
        let session = FocusSession(timerMode: mode)
        session.startedAt = calendar.date(
            byAdding: .day,
            value: -daysAgo,
            to: calendar.startOfDay(for: Date())
        )!.addingTimeInterval(3600) // 오전 1시
        session.wasCompleted = completed
        session.actualDuration = duration
        return session
    }

    // MARK: - filteredSessions 테스트

    func testFilteredSessionsToday() {
        viewModel.selectedPeriod = .today

        let sessions = [
            makeSession(daysAgo: 0),          // 오늘
            makeSession(daysAgo: 1),          // 어제
            makeSession(daysAgo: 7),          // 일주일 전
        ]

        let filtered = viewModel.filteredSessions(from: sessions)
        XCTAssertEqual(filtered.count, 1)
    }

    func testFilteredSessionsWeek() {
        viewModel.selectedPeriod = .week

        let sessions = [
            makeSession(daysAgo: 0),          // 오늘
            makeSession(daysAgo: 3),          // 3일 전 (이번 주 내)
            makeSession(daysAgo: 30),         // 30일 전
        ]

        let filtered = viewModel.filteredSessions(from: sessions)
        // 이번 주 시작일에 따라 2개 이상
        XCTAssertGreaterThanOrEqual(filtered.count, 1)
        XCTAssertLessThanOrEqual(filtered.count, 2)
    }

    func testFilteredSessionsMonth() {
        viewModel.selectedPeriod = .month

        let sessions = [
            makeSession(daysAgo: 0),          // 오늘
            makeSession(daysAgo: 10),         // 10일 전 (이번 달 내)
            makeSession(daysAgo: 60),         // 60일 전
        ]

        let filtered = viewModel.filteredSessions(from: sessions)
        // 이번 달 시작일에 따라 1~2개
        XCTAssertGreaterThanOrEqual(filtered.count, 1)
        XCTAssertLessThanOrEqual(filtered.count, 2)
    }

    // MARK: - 집계 테스트

    func testTotalFocusSeconds() {
        viewModel.selectedPeriod = .today

        let sessions = [
            makeSession(daysAgo: 0, duration: 1500),
            makeSession(daysAgo: 0, duration: 900),
            makeSession(daysAgo: 5, duration: 3600),  // 이번 기간 밖 (today 필터)
        ]

        let total = viewModel.totalFocusSeconds(from: sessions)
        XCTAssertEqual(total, 2400)  // 1500 + 900
    }

    func testSessionCount() {
        viewModel.selectedPeriod = .today

        let sessions = [
            makeSession(daysAgo: 0),
            makeSession(daysAgo: 0),
            makeSession(daysAgo: 3),  // 오늘이 아니므로 제외
        ]

        XCTAssertEqual(viewModel.sessionCount(from: sessions), 2)
    }

    func testCompletionRateWithMixedSessions() {
        viewModel.selectedPeriod = .today

        let sessions = [
            makeSession(daysAgo: 0, completed: true),
            makeSession(daysAgo: 0, completed: true),
            makeSession(daysAgo: 0, completed: false),
        ]

        // 2/3 = 66%
        XCTAssertEqual(viewModel.completionRate(from: sessions), 66)
    }

    func testCompletionRateEmptyReturnsZero() {
        viewModel.selectedPeriod = .today

        let rate = viewModel.completionRate(from: [])
        XCTAssertEqual(rate, 0)
    }

    func testPomodoroRatio() {
        viewModel.selectedPeriod = .today

        let sessions = [
            makeSession(daysAgo: 0, mode: "pomodoro"),
            makeSession(daysAgo: 0, mode: "pomodoro"),
            makeSession(daysAgo: 0, mode: "free"),
            makeSession(daysAgo: 0, mode: "flowmodoro"),
        ]

        // 2/4 = 50%
        XCTAssertEqual(viewModel.pomodoroRatio(from: sessions), 50)
    }

    func testDailyDataGrouping() {
        viewModel.selectedPeriod = .today

        let sessions = [
            makeSession(daysAgo: 0, duration: 600),
            makeSession(daysAgo: 0, duration: 900),
        ]

        let data = viewModel.dailyData(from: sessions)
        XCTAssertEqual(data.count, 1)  // 같은 날 → 1그룹
        XCTAssertEqual(data.first?.focusSeconds, 1500)  // 600 + 900
    }

    func testStreakInfoDelegation() {
        let sessions = [
            makeSession(daysAgo: 0),
            makeSession(daysAgo: 1),
        ]

        let info = viewModel.streakInfo(from: sessions)
        XCTAssertEqual(info.current, 2)
        XCTAssertTrue(info.todayCompleted)
    }
}

// MARK: - DailyFocusEntry 테스트

final class DailyFocusEntryTests: XCTestCase {

    func testFocusMinutesConversion() {
        let entry = DailyFocusEntry(date: Date(), focusSeconds: 1800)
        XCTAssertEqual(entry.focusMinutes, 30.0, accuracy: 0.01)
    }

    func testDayLabelUsesSystemLocale() {
        // 특정 날짜 (2026-02-14 토요일)
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 14
        let date = Calendar.current.date(from: components)!

        let entry = DailyFocusEntry(date: date, focusSeconds: 100)
        // 시스템 로케일에 따라 "토" (Korean) 또는 "Sat" (English) 등
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        let expected = formatter.string(from: date)
        XCTAssertEqual(entry.dayLabel, expected)
    }
}
