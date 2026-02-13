import SwiftUI
import os

// MARK: - 통계 ViewModel (v0.5)

@MainActor
@Observable
final class StatsViewModel {
    enum Period: String, CaseIterable {
        case today = "오늘"
        case week = "이번 주"
        case month = "이번 달"
    }

    var selectedPeriod: Period = .today

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "StatsViewModel"
    )

    // MARK: - 데이터 계산 (세션 배열 기반)

    /// 필터된 세션
    func filteredSessions(from sessions: [FocusSession]) -> [FocusSession] {
        let startDate: Date
        switch selectedPeriod {
        case .today:
            startDate = Date().startOfDay
        case .week:
            startDate = Date().startOfWeek
        case .month:
            startDate = Calendar.current.date(
                from: Calendar.current.dateComponents([.year, .month], from: Date())
            ) ?? Date().startOfDay
        }
        return sessions.filter { $0.startedAt >= startDate }
    }

    /// 총 집중 시간 (초)
    func totalFocusSeconds(from sessions: [FocusSession]) -> Int {
        filteredSessions(from: sessions).reduce(0) { $0 + $1.actualDuration }
    }

    /// 총 세션 수
    func sessionCount(from sessions: [FocusSession]) -> Int {
        filteredSessions(from: sessions).count
    }

    /// 완료율
    func completionRate(from sessions: [FocusSession]) -> Int {
        let filtered = filteredSessions(from: sessions)
        guard !filtered.isEmpty else { return 0 }
        let completed = filtered.filter(\.wasCompleted).count
        return Int((Double(completed) / Double(filtered.count)) * 100)
    }

    /// 자유 vs 뽀모도로 비율 (뽀모도로 비율 %)
    func pomodoroRatio(from sessions: [FocusSession]) -> Int {
        let filtered = filteredSessions(from: sessions)
        guard !filtered.isEmpty else { return 0 }
        let pomodoro = filtered.filter { $0.timerMode == "pomodoro" }.count
        return Int((Double(pomodoro) / Double(filtered.count)) * 100)
    }

    /// 일별 차트 데이터
    func dailyData(from sessions: [FocusSession]) -> [DailyFocusEntry] {
        let filtered = filteredSessions(from: sessions)
        let calendar = Calendar.current

        var grouped: [Date: Int] = [:]
        for session in filtered {
            let day = calendar.startOfDay(for: session.startedAt)
            grouped[day, default: 0] += session.actualDuration
        }

        return grouped
            .map { DailyFocusEntry(date: $0.key, focusSeconds: $0.value) }
            .sorted { $0.date < $1.date }
    }
}

/// 일별 집중 데이터 엔트리
struct DailyFocusEntry: Identifiable {
    let id = UUID()
    let date: Date
    let focusSeconds: Int

    var focusMinutes: Double {
        Double(focusSeconds) / 60.0
    }

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}
