import Foundation
import AppKit
import os

// MARK: - 데이터 내보내기 서비스 (v1.5)

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        }
    }

    var contentType: String {
        switch self {
        case .csv: return "text/csv"
        case .json: return "application/json"
        }
    }
}

@MainActor
enum ExportService {
    private static let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "ExportService"
    )

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - CSV 내보내기

    /// 세션 배열을 CSV 문자열로 변환
    static func exportToCSV(sessions: [FocusSession]) -> String {
        var lines: [String] = []

        // 헤더
        lines.append("Date,Mode,Duration(min),Completed,Intention,Emoji,Rating,Profile")

        // 데이터
        for session in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            let date = dateFormatter.string(from: session.startedAt)
            let mode = session.timerMode
            let duration = String(format: "%.1f", Double(session.actualDuration) / 60.0)
            let completed = session.wasCompleted ? "Yes" : "No"
            let intention = csvEscape(session.intention ?? "")
            let emoji = csvEscape(session.retrospectEmoji ?? "")
            let rating = session.retrospectRating.map { String($0) } ?? ""
            let profile = csvEscape(session.profileName ?? "")

            lines.append("\(date),\(mode),\(duration),\(completed),\(intention),\(emoji),\(rating),\(profile)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - JSON 내보내기

    /// 세션 배열을 JSON 문자열로 변환
    static func exportToJSON(sessions: [FocusSession]) -> String {
        let sorted = sessions.sorted { $0.startedAt < $1.startedAt }

        let entries: [[String: Any]] = sorted.map { session in
            var dict: [String: Any] = [
                "date": isoFormatter.string(from: session.startedAt),
                "mode": session.timerMode,
                "durationSeconds": session.actualDuration,
                "durationMinutes": round(Double(session.actualDuration) / 60.0 * 10) / 10,
                "completed": session.wasCompleted,
                "sessionType": session.sessionType,
            ]

            if let endedAt = session.endedAt {
                dict["endDate"] = isoFormatter.string(from: endedAt)
            }
            if let planned = session.plannedDuration {
                dict["plannedDurationSeconds"] = planned
            }
            if session.overflowDuration > 0 {
                dict["overflowSeconds"] = session.overflowDuration
            }
            if let intention = session.intention, !intention.isEmpty {
                dict["intention"] = intention
            }
            if let emoji = session.retrospectEmoji, !emoji.isEmpty {
                dict["retrospectEmoji"] = emoji
            }
            if let text = session.retrospectText, !text.isEmpty {
                dict["retrospectText"] = text
            }
            if let rating = session.retrospectRating {
                dict["retrospectRating"] = rating
            }
            if let profile = session.profileName, !profile.isEmpty {
                dict["profile"] = profile
            }

            return dict
        }

        let wrapper: [String: Any] = [
            "exportDate": isoFormatter.string(from: Date()),
            "totalSessions": entries.count,
            "sessions": entries,
        ]

        guard let data = try? JSONSerialization.data(
            withJSONObject: wrapper,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            logger.error("JSON 직렬화 실패")
            return "{}"
        }

        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: - 파일 저장 (NSSavePanel)

    /// NSSavePanel로 파일 저장
    static func saveFile(
        content: String,
        format: ExportFormat,
        sessionCount: Int
    ) async -> Bool {
        let panel = NSSavePanel()
        panel.title = String(localized: "export_panel_title")
        panel.nameFieldLabel = String(localized: "export_panel_filename")
        panel.canCreateDirectories = true

        let dateStr = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            return formatter.string(from: Date())
        }()
        panel.nameFieldStringValue = "FocusYou_\(dateStr)_\(sessionCount)sessions.\(format.fileExtension)"

        panel.allowedContentTypes = format == .csv
            ? [.commaSeparatedText]
            : [.json]

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            logger.info("내보내기 취소됨")
            return false
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            logger.info("내보내기 완료: \(url.path)")
            return true
        } catch {
            logger.error("파일 저장 실패: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 유틸리티

    /// CSV 필드 이스케이프 (쉼표, 따옴표, 줄바꿈 포함 시)
    private static func csvEscape(_ value: String) -> String {
        guard !value.isEmpty else { return "" }
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
