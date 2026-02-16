import SwiftUI
import os

// MARK: - 통계 ViewModel (v0.5, v1.5 확장)

@MainActor
@Observable
final class StatsViewModel {
    enum Period: String, CaseIterable {
        case today = "today"
        case week = "week"
        case month = "month"
        case year = "year"

        var displayName: String {
            switch self {
            case .today: String(localized: "stats_today")
            case .week: String(localized: "stats_this_week")
            case .month: String(localized: "stats_this_month")
            case .year: String(localized: "stats_this_year")
            }
        }
    }

    var selectedPeriod: Period = .today

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "StatsViewModel"
    )

    // MARK: - 필터링

    /// 선택된 기간으로 필터된 세션
    func filteredSessions(from sessions: [FocusSession]) -> [FocusSession] {
        let startDate: Date
        let calendar = Calendar.current
        switch selectedPeriod {
        case .today:
            startDate = Date().startOfDay
        case .week:
            startDate = Date().startOfWeek
        case .month:
            startDate = calendar.date(
                from: calendar.dateComponents([.year, .month], from: Date())
            ) ?? Date().startOfDay
        case .year:
            startDate = calendar.date(
                from: calendar.dateComponents([.year], from: Date())
            ) ?? Date().startOfDay
        }
        return sessions.filter { $0.startedAt >= startDate }
    }

    // MARK: - 기본 통계

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

    /// 스트릭 정보
    func streakInfo(from sessions: [FocusSession]) -> StreakCalculator.StreakInfo {
        StreakCalculator.calculate(from: sessions)
    }

    // MARK: - 모드 비율 (v1.5: 3-way)

    /// 모드별 비율 반환 (pomodoro, free, flowmodoro)
    func modeRatios(from sessions: [FocusSession]) -> [ModeRatioEntry] {
        let filtered = filteredSessions(from: sessions)
        guard !filtered.isEmpty else { return [] }

        let total = Double(filtered.count)
        let pomodoro = filtered.filter { $0.timerMode == "pomodoro" }.count
        let flowmodoro = filtered.filter { $0.timerMode == "flowmodoro" }.count
        let free = filtered.count - pomodoro - flowmodoro

        return [
            ModeRatioEntry(modeID: "pomodoro", mode: String(localized: "timer_mode_pomodoro"), count: pomodoro, percent: Int(Double(pomodoro) / total * 100)),
            ModeRatioEntry(modeID: "free", mode: String(localized: "timer_mode_free"), count: free, percent: Int(Double(free) / total * 100)),
            ModeRatioEntry(modeID: "flowmodoro", mode: String(localized: "timer_mode_flowmodoro"), count: flowmodoro, percent: Int(Double(flowmodoro) / total * 100)),
        ].filter { $0.count > 0 }
    }

    /// 레거시 호환: 뽀모도로 비율 (%)
    func pomodoroRatio(from sessions: [FocusSession]) -> Int {
        let filtered = filteredSessions(from: sessions)
        guard !filtered.isEmpty else { return 0 }
        let pomodoro = filtered.filter { $0.timerMode == "pomodoro" }.count
        return Int((Double(pomodoro) / Double(filtered.count)) * 100)
    }

    // MARK: - 차트 데이터

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

    /// 히트맵 데이터 (v1.5): 일별 집중 시간 (시간 단위)
    func heatmapData(from sessions: [FocusSession]) -> [HeatmapEntry] {
        let filtered = filteredSessions(from: sessions)
        let calendar = Calendar.current

        var grouped: [Date: Int] = [:]
        for session in filtered {
            let day = calendar.startOfDay(for: session.startedAt)
            grouped[day, default: 0] += session.actualDuration
        }

        return grouped
            .map { HeatmapEntry(date: $0.key, focusHours: Double($0.value) / 3600.0) }
            .sorted { $0.date < $1.date }
    }

    /// 의도별 분석 (v1.5): 의도별 총 시간 상위 5개
    func intentionBreakdown(from sessions: [FocusSession]) -> [IntentionEntry] {
        let filtered = filteredSessions(from: sessions)
            .filter { $0.intention != nil && !($0.intention?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) }

        var grouped: [String: (seconds: Int, count: Int)] = [:]
        for session in filtered {
            guard let intention = session.intention else { continue }
            let trimmed = intention.trimmingCharacters(in: .whitespaces)
            grouped[trimmed, default: (0, 0)].seconds += session.actualDuration
            grouped[trimmed, default: (0, 0)].count += 1
        }

        return grouped
            .map { IntentionEntry(intention: $0.key, totalSeconds: $0.value.seconds, sessionCount: $0.value.count) }
            .sorted { $0.totalSeconds > $1.totalSeconds }
            .prefix(5)
            .map { $0 }
    }

    /// 월간 트렌드 데이터 (v1.5): 일별 집중 시간
    func monthlyTrendData(from sessions: [FocusSession]) -> [DailyFocusEntry] {
        dailyData(from: sessions)
    }

    /// 전체 누적 집중 시간 (시간, 성장 시스템용)
    func totalFocusHours(from sessions: [FocusSession]) -> Double {
        let total = sessions.reduce(0) { $0 + $1.actualDuration }
        return Double(total) / 3600.0
    }
}

// MARK: - 데이터 엔트리

/// 일별 집중 데이터 엔트리
struct DailyFocusEntry: Identifiable {
    let id = UUID()
    let date: Date
    let focusSeconds: Int

    var focusMinutes: Double {
        Double(focusSeconds) / 60.0
    }

    var focusHours: Double {
        Double(focusSeconds) / 3600.0
    }

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

/// 모드 비율 엔트리 (v1.5)
struct ModeRatioEntry: Identifiable {
    let id = UUID()
    let modeID: String
    let mode: String
    let count: Int
    let percent: Int
}

/// 히트맵 엔트리 (v1.5)
struct HeatmapEntry: Identifiable {
    let id = UUID()
    let date: Date
    let focusHours: Double
}

/// 의도별 분석 엔트리 (v1.5)
struct IntentionEntry: Identifiable {
    let id = UUID()
    let intention: String
    let totalSeconds: Int
    let sessionCount: Int

    var totalMinutes: Double {
        Double(totalSeconds) / 60.0
    }
}
