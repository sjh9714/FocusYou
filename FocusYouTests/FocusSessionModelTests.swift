import XCTest
@testable import Focus_You

final class FocusSessionModelTests: XCTestCase {
    func testInitSetsDefaultValues() {
        let session = FocusSession()

        XCTAssertEqual(session.timerMode, "free")
        XCTAssertNil(session.plannedDuration)
        XCTAssertNil(session.endedAt)
        XCTAssertEqual(session.actualDuration, 0)
        XCTAssertEqual(session.overflowDuration, 0)
        XCTAssertEqual(session.sessionType, "focus")
        XCTAssertFalse(session.wasCompleted)
        XCTAssertNil(session.intention)
        XCTAssertNil(session.retrospectEmoji)
        XCTAssertNil(session.retrospectText)
        XCTAssertNil(session.retrospectRating)
        XCTAssertNil(session.calendarEventID)
        XCTAssertNil(session.profileName)
    }

    func testInitWithCustomParameters() {
        let session = FocusSession(timerMode: "pomodoro", plannedDuration: 1500)

        XCTAssertEqual(session.timerMode, "pomodoro")
        XCTAssertEqual(session.plannedDuration, 1500)
    }

    func testCompleteMarksSessionAsCompleted() {
        let session = FocusSession()
        XCTAssertFalse(session.wasCompleted)
        XCTAssertNil(session.endedAt)

        session.complete(actualDuration: 1200)

        XCTAssertTrue(session.wasCompleted)
        XCTAssertEqual(session.actualDuration, 1200)
        XCTAssertNotNil(session.endedAt)
    }

    func testCancelMarksSessionAsNotCompleted() {
        let session = FocusSession()

        session.cancel(actualDuration: 600)

        XCTAssertFalse(session.wasCompleted)
        XCTAssertEqual(session.actualDuration, 600)
        XCTAssertNotNil(session.endedAt)
    }

    func testCompleteAfterCancelOverridesWasCompleted() {
        let session = FocusSession()

        session.cancel(actualDuration: 300)
        XCTAssertFalse(session.wasCompleted)

        session.complete(actualDuration: 900)
        XCTAssertTrue(session.wasCompleted)
        XCTAssertEqual(session.actualDuration, 900)
    }

    func testCancelAfterCompleteOverridesWasCompleted() {
        let session = FocusSession()

        session.complete(actualDuration: 1500)
        XCTAssertTrue(session.wasCompleted)

        session.cancel(actualDuration: 1500)
        XCTAssertFalse(session.wasCompleted)
    }

    func testStartedAtIsSetOnInit() {
        let before = Date()
        let session = FocusSession()
        let after = Date()

        XCTAssertGreaterThanOrEqual(session.startedAt, before)
        XCTAssertLessThanOrEqual(session.startedAt, after)
    }

    func testEndedAtIsSetOnComplete() {
        let session = FocusSession()
        let before = Date()

        session.complete(actualDuration: 100)

        guard let endedAt = session.endedAt else {
            return XCTFail("endedAt should be set after complete")
        }
        XCTAssertGreaterThanOrEqual(endedAt, before)
        XCTAssertLessThanOrEqual(endedAt, Date())
    }

    func testEndedAtIsSetOnCancel() {
        let session = FocusSession()
        let before = Date()

        session.cancel(actualDuration: 50)

        guard let endedAt = session.endedAt else {
            return XCTFail("endedAt should be set after cancel")
        }
        XCTAssertGreaterThanOrEqual(endedAt, before)
        XCTAssertLessThanOrEqual(endedAt, Date())
    }
}
