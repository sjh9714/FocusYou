import XCTest
@testable import Focus_You

final class StreakCalculatorTests: XCTestCase {
    private let calendar = Calendar.current

    // MARK: - 헬퍼

    /// 특정 날짜에 완료된 세션 생성
    private func makeSession(daysAgo: Int, completed: Bool = true) -> FocusSession {
        let session = FocusSession(timerMode: "free")
        session.startedAt = calendar.date(
            byAdding: .day,
            value: -daysAgo,
            to: calendar.startOfDay(for: Date())
        )!.addingTimeInterval(3600) // 오전 1시
        session.wasCompleted = completed
        session.actualDuration = 1500
        return session
    }

    // MARK: - 테스트

    func testEmptySessionsReturnsZeroStreak() {
        let result = StreakCalculator.calculate(from: [])
        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.longest, 0)
        XCTAssertFalse(result.todayCompleted)
    }

    func testTodayOnlyCompletedReturnsOneDay() {
        let sessions = [makeSession(daysAgo: 0)]
        let result = StreakCalculator.calculate(from: sessions)
        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.longest, 1)
        XCTAssertTrue(result.todayCompleted)
    }

    func testThreeConsecutiveDays() {
        let sessions = [
            makeSession(daysAgo: 0),
            makeSession(daysAgo: 1),
            makeSession(daysAgo: 2),
        ]
        let result = StreakCalculator.calculate(from: sessions)
        XCTAssertEqual(result.current, 3)
        XCTAssertEqual(result.longest, 3)
        XCTAssertTrue(result.todayCompleted)
    }

    func testYesterdayStreakWhenTodayNotCompleted() {
        // 오늘은 아직 미완, 어제까지 3일 연속
        let sessions = [
            makeSession(daysAgo: 1),
            makeSession(daysAgo: 2),
            makeSession(daysAgo: 3),
        ]
        let result = StreakCalculator.calculate(from: sessions)
        // 오늘은 아직 기회가 남았으므로 어제부터 카운트 → 3일
        XCTAssertEqual(result.current, 3)
        XCTAssertEqual(result.longest, 3)
        XCTAssertFalse(result.todayCompleted)
    }

    func testBrokenStreakResetsCount() {
        // 오늘 + 어제 + 3일 전 (2일 전 빠짐)
        let sessions = [
            makeSession(daysAgo: 0),
            makeSession(daysAgo: 1),
            makeSession(daysAgo: 3),
        ]
        let result = StreakCalculator.calculate(from: sessions)
        XCTAssertEqual(result.current, 2) // 오늘 + 어제
        XCTAssertEqual(result.longest, 2)
    }

    func testLongestStreakGreaterThanCurrent() {
        // 과거에 5일 연속, 현재는 2일째
        let sessions = [
            // 현재 스트릭: 오늘 + 어제
            makeSession(daysAgo: 0),
            makeSession(daysAgo: 1),
            // 빈 날: 2일 전
            // 과거 5일 연속: 3~7일 전
            makeSession(daysAgo: 3),
            makeSession(daysAgo: 4),
            makeSession(daysAgo: 5),
            makeSession(daysAgo: 6),
            makeSession(daysAgo: 7),
        ]
        let result = StreakCalculator.calculate(from: sessions)
        XCTAssertEqual(result.current, 2)
        XCTAssertEqual(result.longest, 5)
    }

    func testIncompletedSessionsAreIgnored() {
        let sessions = [
            makeSession(daysAgo: 0, completed: false),
            makeSession(daysAgo: 1, completed: false),
        ]
        let result = StreakCalculator.calculate(from: sessions)
        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.longest, 0)
        XCTAssertFalse(result.todayCompleted)
    }

    func testMixedCompletedAndIncompleted() {
        let sessions = [
            makeSession(daysAgo: 0, completed: true),
            makeSession(daysAgo: 0, completed: false), // 같은 날 취소도 있음
            makeSession(daysAgo: 1, completed: true),
            makeSession(daysAgo: 2, completed: false), // 취소만 → 스트릭 끊김
        ]
        let result = StreakCalculator.calculate(from: sessions)
        XCTAssertEqual(result.current, 2) // 오늘 + 어제
        XCTAssertEqual(result.longest, 2)
        XCTAssertTrue(result.todayCompleted)
    }

    func testMultipleSessionsSameDayCountAsOne() {
        let sessions = [
            makeSession(daysAgo: 0),
            makeSession(daysAgo: 0),
            makeSession(daysAgo: 0),
        ]
        let result = StreakCalculator.calculate(from: sessions)
        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.longest, 1)
    }

    func testOldStreakWithNoRecentActivity() {
        // 10일 전~8일 전 3일 연속, 이후 없음
        let sessions = [
            makeSession(daysAgo: 8),
            makeSession(daysAgo: 9),
            makeSession(daysAgo: 10),
        ]
        let result = StreakCalculator.calculate(from: sessions)
        XCTAssertEqual(result.current, 0) // 어제도 없으므로 0
        XCTAssertEqual(result.longest, 3)
        XCTAssertFalse(result.todayCompleted)
    }

    func testStreakInfoEquatable() {
        let a = StreakCalculator.StreakInfo(current: 3, longest: 5, todayCompleted: true)
        let b = StreakCalculator.StreakInfo(current: 3, longest: 5, todayCompleted: true)
        XCTAssertEqual(a, b)
    }
}
