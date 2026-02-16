import EventKit
import Foundation
import os

// MARK: - Apple Calendar 동기화 서비스 (v1.3)
// 완료된 집중 세션을 Apple Calendar에 자동 기록

@MainActor
@Observable
final class CalendarSyncService {
    static let shared = CalendarSyncService()

    private(set) var hasAccess = false
    private let eventStore = EKEventStore()

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "CalendarSync"
    )

    // MARK: - 권한 요청

    /// 캘린더 접근 권한 요청
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            hasAccess = granted
            if granted {
                logger.info("캘린더 접근 권한 허용")
            } else {
                logger.warning("캘린더 접근 권한 거부")
            }
            return granted
        } catch {
            logger.error("캘린더 권한 요청 실패: \(error.localizedDescription)")
            hasAccess = false
            return false
        }
    }

    // MARK: - 이벤트 생성

    /// 완료된 세션을 캘린더에 기록
    /// - Returns: 생성된 EKEvent의 identifier (실패 시 nil)
    func createEvent(for session: FocusSession) async -> String? {
        if !hasAccess {
            let granted = await requestAccess()
            guard granted else { return nil }
        }

        guard let startedAt = Optional(session.startedAt),
              let endedAt = session.endedAt else {
            logger.warning("세션 시작/종료 시각 없음 — 이벤트 생성 건너뜀")
            return nil
        }

        let calendar = ensureFocusYouCalendar()

        let event = EKEvent(eventStore: eventStore)
        event.title = eventTitle(for: session)
        event.startDate = startedAt
        event.endDate = endedAt
        event.calendar = calendar
        event.notes = eventNotes(for: session)

        do {
            try eventStore.save(event, span: .thisEvent)
            logger.info("캘린더 이벤트 생성: \(event.eventIdentifier ?? "unknown")")
            return event.eventIdentifier
        } catch {
            logger.error("캘린더 이벤트 저장 실패: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private

    /// "Focus You" 전용 캘린더 확보 (없으면 생성)
    private func ensureFocusYouCalendar() -> EKCalendar {
        let calendarTitle = "Focus You"

        // 기존 캘린더 검색
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == calendarTitle }) {
            return existing
        }

        // 새 캘린더 생성
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = calendarTitle
        newCalendar.cgColor = Constants.CalendarSync.calendarColor

        // 기본 소스 선택
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            newCalendar.source = defaultSource
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = localSource
        }

        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            logger.info("Focus You 캘린더 생성 완료")
        } catch {
            logger.error("캘린더 생성 실패: \(error.localizedDescription)")
            return eventStore.defaultCalendarForNewEvents ?? newCalendar
        }

        return newCalendar
    }

    private func eventTitle(for session: FocusSession) -> String {
        let mode = switch session.timerMode {
        case "pomodoro": String(localized: "timer_mode_pomodoro")
        case "flowmodoro": String(localized: "timer_mode_flowmodoro")
        default: String(localized: "calendar_focus")
        }

        let duration = session.actualDuration.formattedAsReadable
        return "\(mode) \(duration)"
    }

    private func eventNotes(for session: FocusSession) -> String {
        var notes = String(localized: "calendar_session_header")

        if let profileName = session.profileName {
            notes += "\n" + String(localized: "calendar_profile \(profileName)")
        }

        if let intention = session.intention, !intention.isEmpty {
            notes += "\n" + String(localized: "calendar_intention \(intention)")
        }

        if let emoji = session.retrospectEmoji {
            notes += "\n" + String(localized: "calendar_retrospect \(emoji)")
        }

        let status = session.wasCompleted
            ? String(localized: "calendar_status_completed")
            : String(localized: "calendar_status_cancelled")
        notes += "\n" + String(localized: "calendar_status \(status)")
        return notes
    }
}

// MARK: - Int Duration Helper

private extension Int {
    var formattedAsReadable: String {
        let minutes = self / 60
        if minutes < 60 {
            return String(localized: "duration_minutes \(minutes)")
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return String(localized: "duration_hours_minutes \(hours) \(remainingMinutes)")
    }
}
