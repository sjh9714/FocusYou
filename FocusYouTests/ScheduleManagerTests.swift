import Foundation
import Testing
@testable import Focus_You

// MARK: - ScheduleManager 테스트 (v1.3)

@Suite("ScheduleManager")
@MainActor
struct ScheduleManagerTests {

    // MARK: - 모니터링 상태

    @Test("초기 상태: 모니터링 비활성")
    func testInitialState() {
        let manager = ScheduleManager()
        #expect(manager.isMonitoring == false)
    }

    @Test("stopMonitoring: 모니터링 중지")
    func testStopMonitoring() {
        let manager = ScheduleManager()
        manager.stopMonitoring()
        #expect(manager.isMonitoring == false)
    }

    // MARK: - BlockSchedule 모델 로직

    @Test("weekdayArray 파싱: 월~금")
    func testWeekdayArray_weekdays() throws {
        let schedule = BlockSchedule(name: "테스트", weekdays: "2,3,4,5,6")
        #expect(schedule.weekdayArray == [2, 3, 4, 5, 6])
    }

    @Test("weekdayArray 파싱: 전체 요일")
    func testWeekdayArray_allDays() {
        let schedule = BlockSchedule(name: "매일", weekdays: "1,2,3,4,5,6,7")
        #expect(schedule.weekdayArray.count == 7)
    }

    @Test("weekdayArray 파싱: 빈 문자열")
    func testWeekdayArray_empty() {
        let schedule = BlockSchedule(name: "없음", weekdays: "")
        #expect(schedule.weekdayArray.isEmpty)
    }

    @Test("startTimeFormatted: 09:00")
    func testStartTimeFormatted() {
        let schedule = BlockSchedule(
            name: "오전",
            startMinuteOfDay: 540,  // 9 * 60
            endMinuteOfDay: 720
        )
        #expect(schedule.startTimeFormatted == "09:00")
    }

    @Test("endTimeFormatted: 12:00")
    func testEndTimeFormatted() {
        let schedule = BlockSchedule(
            name: "오전",
            startMinuteOfDay: 540,
            endMinuteOfDay: 720  // 12 * 60
        )
        #expect(schedule.endTimeFormatted == "12:00")
    }

    @Test("시간 포맷: 자정(00:00)")
    func testTimeFormatted_midnight() {
        let schedule = BlockSchedule(
            name: "심야",
            startMinuteOfDay: 0,
            endMinuteOfDay: 60
        )
        #expect(schedule.startTimeFormatted == "00:00")
        #expect(schedule.endTimeFormatted == "01:00")
    }

    @Test("시간 포맷: 23:59")
    func testTimeFormatted_endOfDay() {
        let schedule = BlockSchedule(
            name: "하루 끝",
            startMinuteOfDay: 1380,
            endMinuteOfDay: 1439  // 23:59
        )
        #expect(schedule.startTimeFormatted == "23:00")
        #expect(schedule.endTimeFormatted == "23:59")
    }

    @Test("기본값: 월~금, 09:00~12:00")
    func testDefaultValues() {
        let schedule = BlockSchedule(name: "기본")
        #expect(schedule.weekdays == "2,3,4,5,6")
        #expect(schedule.startMinuteOfDay == 540)
        #expect(schedule.endMinuteOfDay == 720)
        #expect(schedule.isEnabled == true)
    }

    // MARK: - 스케줄 체크 간격

    @Test("체크 간격 상수: 60초")
    func testCheckInterval() {
        #expect(Constants.Schedule.checkIntervalSeconds == 60)
    }

    // MARK: - 스케줄 시간 범위 로직

    @Test("시간 범위 내 확인: startMinute <= current < endMinute")
    func testTimeRange_within() {
        let schedule = BlockSchedule(
            name: "오전",
            startMinuteOfDay: 540,
            endMinuteOfDay: 720
        )
        let currentMinute = 600  // 10:00
        let isInRange = currentMinute >= schedule.startMinuteOfDay
            && currentMinute < schedule.endMinuteOfDay
        #expect(isInRange == true)
    }

    @Test("시간 범위 밖: current >= endMinute")
    func testTimeRange_after() {
        let schedule = BlockSchedule(
            name: "오전",
            startMinuteOfDay: 540,
            endMinuteOfDay: 720
        )
        let currentMinute = 720  // 12:00 (endMinuteOfDay와 같으면 범위 밖)
        let isInRange = currentMinute >= schedule.startMinuteOfDay
            && currentMinute < schedule.endMinuteOfDay
        #expect(isInRange == false)
    }

    @Test("시간 범위 밖: current < startMinute")
    func testTimeRange_before() {
        let schedule = BlockSchedule(
            name: "오전",
            startMinuteOfDay: 540,
            endMinuteOfDay: 720
        )
        let currentMinute = 480  // 08:00
        let isInRange = currentMinute >= schedule.startMinuteOfDay
            && currentMinute < schedule.endMinuteOfDay
        #expect(isInRange == false)
    }

    @Test("시간 범위 경계: 정확히 startMinute")
    func testTimeRange_exactStart() {
        let schedule = BlockSchedule(
            name: "오전",
            startMinuteOfDay: 540,
            endMinuteOfDay: 720
        )
        let currentMinute = 540  // 09:00
        let isInRange = currentMinute >= schedule.startMinuteOfDay
            && currentMinute < schedule.endMinuteOfDay
        #expect(isInRange == true)
    }

    // MARK: - 요일 매칭 로직

    @Test("요일 포함 확인: 월요일(2) in 월~금")
    func testWeekdayContains_monday() {
        let schedule = BlockSchedule(name: "평일", weekdays: "2,3,4,5,6")
        #expect(schedule.weekdayArray.contains(2) == true)
    }

    @Test("요일 미포함 확인: 일요일(1) not in 월~금")
    func testWeekdayContains_sunday() {
        let schedule = BlockSchedule(name: "평일", weekdays: "2,3,4,5,6")
        #expect(schedule.weekdayArray.contains(1) == false)
    }

    @Test("요일 미포함 확인: 토요일(7) not in 월~금")
    func testWeekdayContains_saturday() {
        let schedule = BlockSchedule(name: "평일", weekdays: "2,3,4,5,6")
        #expect(schedule.weekdayArray.contains(7) == false)
    }
}
