import Foundation
import SwiftData
import Testing
@testable import Focus_You

// MARK: - ExportService 테스트 (v1.5)

@Suite("ExportService")
@MainActor
struct ExportServiceTests {

    /// 테스트용 ModelContainer (인메모리)
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: BlockProfile.self,
            BlockedSite.self,
            BlockedApp.self,
            FocusSession.self,
            BlockSchedule.self,
            Badge.self,
            configurations: config
        )
    }

    /// 테스트용 세션 생성
    private func makeSessions(container: ModelContainer) -> [FocusSession] {
        let ctx = container.mainContext

        let session1 = FocusSession(timerMode: "free", plannedDuration: 1800)
        session1.startedAt = makeDate(2024, 1, 15, 9, 0)
        session1.endedAt = makeDate(2024, 1, 15, 9, 30)
        session1.actualDuration = 1800
        session1.wasCompleted = true
        session1.sessionType = "focus"
        session1.intention = "코딩"
        session1.profileName = "업무"
        ctx.insert(session1)

        let session2 = FocusSession(timerMode: "pomodoro", plannedDuration: 1500)
        session2.startedAt = makeDate(2024, 1, 15, 10, 0)
        session2.endedAt = makeDate(2024, 1, 15, 10, 25)
        session2.actualDuration = 1500
        session2.wasCompleted = false
        session2.sessionType = "focus"
        session2.retrospectEmoji = "😊"
        session2.retrospectRating = 4
        ctx.insert(session2)

        return [session1, session2]
    }

    private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        comps.hour = h; comps.minute = min; comps.second = 0
        comps.timeZone = TimeZone(identifier: "Asia/Seoul")
        return Calendar.current.date(from: comps)!
    }

    private func jsonObject(from json: String) throws -> [String: Any] {
        let data = try #require(json.data(using: .utf8))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func jsonSessions(from object: [String: Any]) throws -> [[String: Any]] {
        try #require(object["sessions"] as? [[String: Any]])
    }

    // MARK: - CSV 테스트

    @Test("CSV 헤더 포함")
    func testCSV_header() throws {
        let container = try makeContainer()
        let sessions = makeSessions(container: container)
        let csv = ExportService.exportToCSV(sessions: sessions)
        let lines = csv.components(separatedBy: "\n")
        #expect(lines[0] == "Date,Mode,Duration(min),Completed,Intention,Emoji,Rating,Profile")
    }

    @Test("CSV 데이터 행 수 = 세션 수")
    func testCSV_rowCount() throws {
        let container = try makeContainer()
        let sessions = makeSessions(container: container)
        let csv = ExportService.exportToCSV(sessions: sessions)
        let lines = csv.components(separatedBy: "\n")
        // 헤더 1줄 + 데이터 2줄 = 3줄
        #expect(lines.count == 3)
    }

    @Test("CSV 날짜 오름차순 정렬")
    func testCSV_sortedByDate() throws {
        let container = try makeContainer()
        let sessions = makeSessions(container: container)
        let csv = ExportService.exportToCSV(sessions: sessions)
        let lines = csv.components(separatedBy: "\n")
        // 첫 데이터 행이 session1 (09:00), 두 번째가 session2 (10:00)
        #expect(lines[1].contains("free"))
        #expect(lines[2].contains("pomodoro"))
    }

    @Test("CSV Completed 필드")
    func testCSV_completedField() throws {
        let container = try makeContainer()
        let sessions = makeSessions(container: container)
        let csv = ExportService.exportToCSV(sessions: sessions)
        let lines = csv.components(separatedBy: "\n")
        #expect(lines[1].contains("Yes"))  // session1: completed
        #expect(lines[2].contains("No"))   // session2: not completed
    }

    @Test("CSV 빈 세션 배열: 헤더만 반환")
    func testCSV_emptySessions() {
        let csv = ExportService.exportToCSV(sessions: [])
        let lines = csv.components(separatedBy: "\n")
        #expect(lines.count == 1)
        #expect(lines[0].hasPrefix("Date,"))
    }

    @Test("CSV 쉼표 포함 문자열 이스케이프")
    func testCSV_escapeComma() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let session = FocusSession(timerMode: "free")
        session.startedAt = makeDate(2024, 1, 1, 0, 0)
        session.actualDuration = 60
        session.wasCompleted = true
        session.sessionType = "focus"
        session.intention = "코딩, 리뷰"
        ctx.insert(session)

        let csv = ExportService.exportToCSV(sessions: [session])
        // 쉼표 포함 → "코딩, 리뷰" (따옴표로 감싸야 함)
        #expect(csv.contains("\"코딩, 리뷰\""))
    }

    @Test("CSV Duration 소수점 포맷")
    func testCSV_durationFormat() throws {
        let container = try makeContainer()
        let sessions = makeSessions(container: container)
        let csv = ExportService.exportToCSV(sessions: sessions)
        // 1800초 = 30.0분
        #expect(csv.contains("30.0"))
        // 1500초 = 25.0분
        #expect(csv.contains("25.0"))
    }

    // MARK: - JSON 테스트

    @Test("JSON 유효한 형식")
    func testJSON_valid() throws {
        let container = try makeContainer()
        let sessions = makeSessions(container: container)
        let json = ExportService.exportToJSON(sessions: sessions)
        let obj = try jsonObject(from: json)
        #expect(!obj.isEmpty)
    }

    @Test("JSON totalSessions 필드")
    func testJSON_totalSessions() throws {
        let container = try makeContainer()
        let sessions = makeSessions(container: container)
        let json = ExportService.exportToJSON(sessions: sessions)
        let obj = try jsonObject(from: json)
        #expect(obj["totalSessions"] as? Int == 2)
    }

    @Test("JSON sessions 배열 포함")
    func testJSON_sessionsArray() throws {
        let container = try makeContainer()
        let sessions = makeSessions(container: container)
        let json = ExportService.exportToJSON(sessions: sessions)
        let obj = try jsonObject(from: json)
        let arr = try jsonSessions(from: obj)
        #expect(arr.count == 2)
    }

    @Test("JSON exportDate 포함")
    func testJSON_exportDate() throws {
        let container = try makeContainer()
        let sessions = makeSessions(container: container)
        let json = ExportService.exportToJSON(sessions: sessions)
        let obj = try jsonObject(from: json)
        #expect(obj["exportDate"] is String)
    }

    @Test("JSON 빈 세션 배열")
    func testJSON_emptySessions() throws {
        let json = ExportService.exportToJSON(sessions: [])
        let obj = try jsonObject(from: json)
        #expect(obj["totalSessions"] as? Int == 0)
        let arr = try jsonSessions(from: obj)
        #expect(arr.isEmpty)
    }

    @Test("JSON optional 필드: intention 포함")
    func testJSON_optionalFields() throws {
        let container = try makeContainer()
        let sessions = makeSessions(container: container)
        let json = ExportService.exportToJSON(sessions: sessions)
        let obj = try jsonObject(from: json)
        let arr = try jsonSessions(from: obj)
        // session1: intention = "코딩"
        let first = arr[0]
        #expect(first["intention"] as? String == "코딩")
        // session2: intention nil → 키 없음
        let second = arr[1]
        #expect(second["intention"] == nil)
    }

    @Test("JSON mode 필드")
    func testJSON_modeField() throws {
        let container = try makeContainer()
        let sessions = makeSessions(container: container)
        let json = ExportService.exportToJSON(sessions: sessions)
        let obj = try jsonObject(from: json)
        let arr = try jsonSessions(from: obj)
        #expect(arr[0]["mode"] as? String == "free")
        #expect(arr[1]["mode"] as? String == "pomodoro")
    }

    // MARK: - ExportFormat

    @Test("ExportFormat CSV 속성")
    func testExportFormat_csv() {
        #expect(ExportFormat.csv.rawValue == "CSV")
        #expect(ExportFormat.csv.fileExtension == "csv")
        #expect(ExportFormat.csv.contentType == "text/csv")
    }

    @Test("ExportFormat JSON 속성")
    func testExportFormat_json() {
        #expect(ExportFormat.json.rawValue == "JSON")
        #expect(ExportFormat.json.fileExtension == "json")
        #expect(ExportFormat.json.contentType == "application/json")
    }

    @Test("ExportFormat.allCases = 2개")
    func testExportFormat_allCases() {
        #expect(ExportFormat.allCases.count == 2)
    }
}
