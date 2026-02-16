import XCTest
@testable import Focus_You

final class BlockScheduleModelTests: XCTestCase {

    func testWeekdayArrayParsesCorrectly() {
        let schedule = BlockSchedule(name: "테스트", weekdays: "2,3,4,5,6")
        XCTAssertEqual(schedule.weekdayArray, [2, 3, 4, 5, 6])
    }

    func testWeekdayArrayHandlesAllDays() {
        let schedule = BlockSchedule(name: "매일", weekdays: "1,2,3,4,5,6,7")
        XCTAssertEqual(schedule.weekdayArray.count, 7)
        XCTAssertEqual(schedule.weekdayArray.first, 1)
        XCTAssertEqual(schedule.weekdayArray.last, 7)
    }

    func testWeekdayArrayHandlesEmptyString() {
        let schedule = BlockSchedule(name: "빈 스케줄", weekdays: "")
        XCTAssertTrue(schedule.weekdayArray.isEmpty)
    }

    func testStartTimeFormatted() {
        let schedule = BlockSchedule(name: "오전", startMinuteOfDay: 540) // 09:00
        XCTAssertEqual(schedule.startTimeFormatted, "09:00")
    }

    func testEndTimeFormatted() {
        let schedule = BlockSchedule(name: "오후", endMinuteOfDay: 780) // 13:00
        XCTAssertEqual(schedule.endTimeFormatted, "13:00")
    }

    func testMidnightTimeFormatted() {
        let schedule = BlockSchedule(name: "자정", startMinuteOfDay: 0, endMinuteOfDay: 60)
        XCTAssertEqual(schedule.startTimeFormatted, "00:00")
        XCTAssertEqual(schedule.endTimeFormatted, "01:00")
    }

    func testDefaultWeekdaysAreWeekdays() {
        let schedule = BlockSchedule(name: "기본")
        XCTAssertEqual(schedule.weekdays, "2,3,4,5,6")
        XCTAssertEqual(schedule.weekdayArray, [2, 3, 4, 5, 6])
    }

    func testDefaultTimesAre9To12() {
        let schedule = BlockSchedule(name: "기본")
        XCTAssertEqual(schedule.startMinuteOfDay, 540)
        XCTAssertEqual(schedule.endMinuteOfDay, 720)
    }

    func testIsEnabledDefaultsToTrue() {
        let schedule = BlockSchedule(name: "활성")
        XCTAssertTrue(schedule.isEnabled)
    }

    func testWeekdayDisplayText() {
        let schedule = BlockSchedule(name: "평일", weekdays: "2,3,4,5,6")
        let expected = [
            String(localized: "weekday_mon"), String(localized: "weekday_tue"),
            String(localized: "weekday_wed"), String(localized: "weekday_thu"),
            String(localized: "weekday_fri"),
        ].joined()
        XCTAssertEqual(schedule.weekdayDisplayText, expected)
    }

    func testWeekdayDisplayTextSingleDay() {
        let schedule = BlockSchedule(name: "일요일", weekdays: "1")
        XCTAssertEqual(schedule.weekdayDisplayText, String(localized: "weekday_sun"))
    }

    func testWeekdayDisplayTextAllDays() {
        let schedule = BlockSchedule(name: "매일", weekdays: "1,2,3,4,5,6,7")
        let expected = [
            String(localized: "weekday_sun"), String(localized: "weekday_mon"),
            String(localized: "weekday_tue"), String(localized: "weekday_wed"),
            String(localized: "weekday_thu"), String(localized: "weekday_fri"),
            String(localized: "weekday_sat"),
        ].joined()
        XCTAssertEqual(schedule.weekdayDisplayText, expected)
    }
}
