import Foundation

// MARK: - 스트릭 계산기 (v1.0)
// 순수 함수 기반 — FocusSession 배열에서 연속 집중 일수를 계산

enum StreakCalculator {

    /// 스트릭 정보
    struct StreakInfo: Equatable, Sendable {
        /// 현재 연속 일수
        let current: Int
        /// 최장 연속 일수
        let longest: Int
        /// 오늘 완료 세션이 있는지 여부
        let todayCompleted: Bool
    }

    /// 세션 배열에서 스트릭 정보를 계산
    /// - Parameter sessions: 전체 FocusSession 배열
    /// - Returns: 현재/최장 스트릭 및 오늘 완료 여부
    static func calculate(from sessions: [FocusSession]) -> StreakInfo {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 1. 완료된 세션만 필터 → 날짜 Set 생성
        let completedDates = Set(
            sessions
                .filter(\.wasCompleted)
                .map { calendar.startOfDay(for: $0.startedAt) }
        )

        guard !completedDates.isEmpty else {
            return StreakInfo(current: 0, longest: 0, todayCompleted: false)
        }

        let todayCompleted = completedDates.contains(today)

        // 2. 현재 스트릭: 오늘 또는 어제부터 역순 카운트
        let currentStreak = countConsecutiveDays(
            from: todayCompleted ? today : calendar.date(byAdding: .day, value: -1, to: today)!,
            completedDates: completedDates,
            calendar: calendar
        )

        // 3. 최장 스트릭: 모든 날짜를 정렬 후 가장 긴 연속 구간 찾기
        let longestStreak = findLongestStreak(
            completedDates: completedDates,
            calendar: calendar
        )

        return StreakInfo(
            current: currentStreak,
            longest: max(longestStreak, currentStreak),
            todayCompleted: todayCompleted
        )
    }

    // MARK: - Private

    /// 특정 날짜부터 과거로 연속된 날 수 카운트
    private static func countConsecutiveDays(
        from startDate: Date,
        completedDates: Set<Date>,
        calendar: Calendar
    ) -> Int {
        var count = 0
        var checkDate = startDate

        while completedDates.contains(checkDate) {
            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay
        }

        return count
    }

    /// 전체 기간에서 가장 긴 연속 구간 찾기
    private static func findLongestStreak(
        completedDates: Set<Date>,
        calendar: Calendar
    ) -> Int {
        let sortedDates = completedDates.sorted()
        guard !sortedDates.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<sortedDates.count {
            let daysBetween = calendar.dateComponents(
                [.day],
                from: sortedDates[i - 1],
                to: sortedDates[i]
            ).day ?? 0

            if daysBetween == 1 {
                current += 1
                longest = max(longest, current)
            } else if daysBetween > 1 {
                current = 1
            }
            // daysBetween == 0은 같은 날 → 무시 (Set이므로 발생하지 않음)
        }

        return longest
    }
}
