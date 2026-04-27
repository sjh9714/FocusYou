import XCTest
import SwiftData
@testable import Focus_You

@MainActor
final class CalendarSyncServiceTests: XCTestCase {
    private var service: CalendarSyncService!

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            service = CalendarSyncService.shared
        }
    }

    // MARK: - eventTitle

    func testEventTitleForFreeMode() {
        let session = FocusSession(timerMode: "free", plannedDuration: 1500)
        session.complete(actualDuration: 1500)
        let title = service.eventTitle(for: session)
        XCTAssertFalse(title.isEmpty)
        // free 모드는 "집중" 키워드 포함
        XCTAssertTrue(title.contains("25"))
    }

    func testEventTitleForPomodoroMode() {
        let session = FocusSession(timerMode: "pomodoro", plannedDuration: 1500)
        session.complete(actualDuration: 1500)
        let title = service.eventTitle(for: session)
        XCTAssertFalse(title.isEmpty)
    }

    func testEventTitleForFlowmodoroMode() {
        let session = FocusSession(timerMode: "flowmodoro", plannedDuration: nil)
        session.complete(actualDuration: 2700)
        let title = service.eventTitle(for: session)
        XCTAssertFalse(title.isEmpty)
    }

    // MARK: - eventNotes

    func testEventNotesIncludesProfileName() {
        let session = FocusSession(timerMode: "free", plannedDuration: 1500)
        session.profileName = "Work"
        session.complete(actualDuration: 1500)
        let notes = service.eventNotes(for: session)
        XCTAssertTrue(notes.contains("Work"))
    }

    func testEventNotesIncludesIntention() {
        let session = FocusSession(timerMode: "free", plannedDuration: 1500)
        session.intention = "코딩 집중"
        session.complete(actualDuration: 1500)
        let notes = service.eventNotes(for: session)
        XCTAssertTrue(notes.contains("코딩 집중"))
    }

    func testEventNotesIncludesRetrospectEmoji() {
        let session = FocusSession(timerMode: "free", plannedDuration: 1500)
        session.retrospectEmoji = "🔥"
        session.complete(actualDuration: 1500)
        let notes = service.eventNotes(for: session)
        XCTAssertTrue(notes.contains("🔥"))
    }
}
