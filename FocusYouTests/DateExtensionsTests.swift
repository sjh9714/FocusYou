import XCTest
@testable import Focus_You

final class DateExtensionsTests: XCTestCase {

    // MARK: - TimeInterval.formattedAsTimer

    func testFormattedAsTimerStandard() {
        XCTAssertEqual(TimeInterval(1500).formattedAsTimer, "25:00")
    }

    func testFormattedAsTimerUnderMinute() {
        XCTAssertEqual(TimeInterval(45).formattedAsTimer, "00:45")
    }

    func testFormattedAsTimerZero() {
        XCTAssertEqual(TimeInterval(0).formattedAsTimer, "00:00")
    }

    func testFormattedAsTimerLarge() {
        // 61분 1초
        XCTAssertEqual(TimeInterval(3661).formattedAsTimer, "61:01")
    }

    // MARK: - TimeInterval.formattedAsReadable

    func testFormattedAsReadableMinutesOnly() {
        XCTAssertEqual(TimeInterval(1500).formattedAsReadable, String(localized: "duration_minutes \(25)"))
    }

    func testFormattedAsReadableWithHours() {
        XCTAssertEqual(TimeInterval(3660).formattedAsReadable, String(localized: "duration_hours_minutes \(1) \(1)"))
    }

    func testFormattedAsReadableZero() {
        XCTAssertEqual(TimeInterval(0).formattedAsReadable, String(localized: "duration_minutes \(0)"))
    }

    func testFormattedAsReadableExactHour() {
        XCTAssertEqual(TimeInterval(3600).formattedAsReadable, String(localized: "duration_hours_minutes \(1) \(0)"))
    }

    // MARK: - Date.startOfDay

    func testStartOfDay() {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 14
        components.hour = 15
        components.minute = 30
        let date = Calendar.current.date(from: components)!

        let result = date.startOfDay
        let resultComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: result
        )

        XCTAssertEqual(resultComponents.year, 2026)
        XCTAssertEqual(resultComponents.month, 2)
        XCTAssertEqual(resultComponents.day, 14)
        XCTAssertEqual(resultComponents.hour, 0)
        XCTAssertEqual(resultComponents.minute, 0)
        XCTAssertEqual(resultComponents.second, 0)
    }

    // MARK: - Date.startOfWeek

    func testStartOfWeekIsBeforeOrEqualToDate() {
        let now = Date()
        let weekStart = now.startOfWeek
        XCTAssertLessThanOrEqual(weekStart, now)

        // 같은 주 시작일이므로 7일 이내
        let diff = now.timeIntervalSince(weekStart)
        XCTAssertLessThan(diff, 7 * 24 * 3600)
    }
}
