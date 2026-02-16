import Foundation
import Testing
@testable import Focus_You

// MARK: - BurnoutDetector 테스트 (v1.5)

@Suite("BurnoutDetector")
@MainActor
struct BurnoutDetectorTests {

    // MARK: - checkBurnoutStatus (순수 로직)

    @Test("안전 상태: 오늘 0분 집중")
    func testStatus_safe_zeroFocus() {
        let detector = BurnoutDetector()
        let status = detector.checkBurnoutStatus(
            todayFocusSeconds: 0,
            dailyLimitHours: 6.0
        )
        #expect(status == .safe)
    }

    @Test("안전 상태: 한계의 절반 이하")
    func testStatus_safe_halfLimit() {
        let detector = BurnoutDetector()
        // 6시간 한계, 2시간(7200초) 집중
        let status = detector.checkBurnoutStatus(
            todayFocusSeconds: 7200,
            dailyLimitHours: 6.0
        )
        #expect(status == .safe)
    }

    @Test("접근 경고: 한계까지 30분 이내 남음")
    func testStatus_approaching() {
        let detector = BurnoutDetector()
        // 6시간(21600초) 한계, 20400초(5시간 40분) 집중 → 남은 20분
        let status = detector.checkBurnoutStatus(
            todayFocusSeconds: 20400,
            dailyLimitHours: 6.0
        )
        #expect(status == .approaching(remainingMinutes: 20))
    }

    @Test("접근 경고: 정확히 30분 남음")
    func testStatus_approaching_exactly30min() {
        let detector = BurnoutDetector()
        // 6시간 한계, 19800초(5시간 30분) 집중 → 남은 30분
        let status = detector.checkBurnoutStatus(
            todayFocusSeconds: 19800,
            dailyLimitHours: 6.0
        )
        #expect(status == .approaching(remainingMinutes: 30))
    }

    @Test("초과 상태: 한계 초과")
    func testStatus_exceeded() {
        let detector = BurnoutDetector()
        // 6시간(21600초) 한계, 23400초(6시간 30분) 집중 → 30분 초과
        let status = detector.checkBurnoutStatus(
            todayFocusSeconds: 23400,
            dailyLimitHours: 6.0
        )
        #expect(status == .exceeded(overageMinutes: 30))
    }

    @Test("초과 상태: 정확히 한계")
    func testStatus_exceeded_exactLimit() {
        let detector = BurnoutDetector()
        // 6시간(21600초) 한계, 정확히 21600초 집중
        let status = detector.checkBurnoutStatus(
            todayFocusSeconds: 21600,
            dailyLimitHours: 6.0
        )
        #expect(status == .exceeded(overageMinutes: 0))
    }

    @Test("접근 경고: remainingMinutes 최소 1")
    func testStatus_approaching_minimumOneMinute() {
        let detector = BurnoutDetector()
        // 한계까지 10초 남음 → 0.17분 → max(_, 1) = 1분
        let status = detector.checkBurnoutStatus(
            todayFocusSeconds: 21590,
            dailyLimitHours: 6.0
        )
        #expect(status == .approaching(remainingMinutes: 1))
    }

    // MARK: - calculateBalanceScore

    @Test("빈 세션 배열 → 100점")
    func testBalanceScore_empty() {
        let detector = BurnoutDetector()
        let score = detector.calculateBalanceScore(sessions: [])
        #expect(score == 100)
    }

    @Test("집중만 있고 휴식 없으면 점수 낮음")
    func testBalanceScore_noBreaks() {
        let detector = BurnoutDetector()
        let now = Date()
        let sessions = [
            FocusSessionData(startedAt: now, actualDuration: 3600, sessionType: "focus"),
        ]
        let score = detector.calculateBalanceScore(sessions: sessions)
        // actualRatio = 0, idealRatio = 0.2, deviation = 0.2, score = 100 - 40 = 60
        #expect(score == 60)
    }

    @Test("이상적 비율 (5:1) → 100점")
    func testBalanceScore_idealRatio() {
        let detector = BurnoutDetector()
        let now = Date()
        let sessions = [
            FocusSessionData(startedAt: now, actualDuration: 5000, sessionType: "focus"),
            FocusSessionData(startedAt: now, actualDuration: 1000, sessionType: "break"),
        ]
        let score = detector.calculateBalanceScore(sessions: sessions)
        #expect(score == 100)
    }

    @Test("7일 이전 세션은 제외")
    func testBalanceScore_excludesOldSessions() {
        let detector = BurnoutDetector()
        let oldDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        let sessions = [
            FocusSessionData(startedAt: oldDate, actualDuration: 36000, sessionType: "focus"),
        ]
        let score = detector.calculateBalanceScore(sessions: sessions)
        // 최근 7일 세션 없으므로 100점
        #expect(score == 100)
    }

    @Test("균형 점수 범위: 0~100")
    func testBalanceScore_range() {
        let detector = BurnoutDetector()
        let now = Date()
        // 극단적 불균형: 집중 많고 휴식 없음
        let sessions = [
            FocusSessionData(startedAt: now, actualDuration: 36000, sessionType: "focus"),
        ]
        let score = detector.calculateBalanceScore(sessions: sessions)
        #expect(score >= 0 && score <= 100)
    }

    // MARK: - 스트레칭 알림

    @Test("90분 미만: 스트레칭 알림 불필요")
    func testStretchReminder_below90min() {
        let suiteName = "test.burnout.stretch.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: Constants.Settings.enableBurnoutWarningsKey)

        let detector = BurnoutDetector()
        detector.resetSession()
        // 89분 59초 = 5399초 < 5400초 threshold
        let result = detector.shouldShowStretchReminder(elapsedSeconds: 5399)
        // 기본 isEnabled를 사용하므로 직접 판단
        // 참고: BurnoutDetector는 내부 defaults를 사용하므로 테스트는 기본값(true)에 의존
        #expect(result == false)

        defaults.removeSuite(named: suiteName)
    }

    @Test("90분 이상: 스트레칭 알림 필요 (첫 번째)")
    func testStretchReminder_at90min() {
        let detector = BurnoutDetector()
        detector.resetSession()
        let result = detector.shouldShowStretchReminder(elapsedSeconds: 5400)
        #expect(result == true)
    }

    @Test("markStretchReminderSent 후 재알림 안 됨")
    func testStretchReminder_sentOnce() {
        let detector = BurnoutDetector()
        detector.resetSession()
        #expect(detector.shouldShowStretchReminder(elapsedSeconds: 5400) == true)
        detector.markStretchReminderSent()
        #expect(detector.shouldShowStretchReminder(elapsedSeconds: 6000) == false)
    }

    @Test("resetSession 후 알림 다시 활성화")
    func testStretchReminder_resetReenables() {
        let detector = BurnoutDetector()
        detector.resetSession()
        detector.markStretchReminderSent()
        #expect(detector.shouldShowStretchReminder(elapsedSeconds: 5400) == false)

        detector.resetSession()
        #expect(detector.shouldShowStretchReminder(elapsedSeconds: 5400) == true)
    }

    // MARK: - BurnoutStatus Equatable

    @Test("BurnoutStatus.safe == .safe")
    func testStatusEquatable_safe() {
        #expect(BurnoutDetector.BurnoutStatus.safe == .safe)
    }

    @Test("BurnoutStatus.approaching 값 비교")
    func testStatusEquatable_approaching() {
        #expect(
            BurnoutDetector.BurnoutStatus.approaching(remainingMinutes: 10)
                == .approaching(remainingMinutes: 10)
        )
        #expect(
            BurnoutDetector.BurnoutStatus.approaching(remainingMinutes: 10)
                != .approaching(remainingMinutes: 20)
        )
    }

    @Test("BurnoutStatus.exceeded 값 비교")
    func testStatusEquatable_exceeded() {
        #expect(
            BurnoutDetector.BurnoutStatus.exceeded(overageMinutes: 5)
                == .exceeded(overageMinutes: 5)
        )
    }
}
