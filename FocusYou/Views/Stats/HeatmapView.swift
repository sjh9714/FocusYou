import SwiftUI

// MARK: - 히트맵 뷰 (v1.5)
// GitHub 스타일 캘린더 히트맵. 일별 집중 강도를 색상으로 표시.

struct HeatmapView: View {
    let data: [HeatmapEntry]
    @Environment(ThemeManager.self) private var themeManager

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdays = Constants.Schedule.weekdaySymbols

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Text("집중 히트맵")
                .font(.headline)

            if data.isEmpty {
                emptyState
            } else {
                heatmapGrid
                legend
            }
        }
        .frostedCard()
    }

    // MARK: - 히트맵 그리드

    private var heatmapGrid: some View {
        VStack(spacing: 2) {
            // 요일 헤더
            HStack(spacing: 2) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 날짜 셀 그리드
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(calendarDays, id: \.self) { date in
                    cellView(for: date)
                }
            }
        }
    }

    private func cellView(for date: Date) -> some View {
        let hours = hoursForDate(date)
        let intensity = intensityLevel(hours: hours)
        let isToday = Calendar.current.isDateInToday(date)
        let isFuture = date > Date()

        return RoundedRectangle(cornerRadius: 2)
            .fill(isFuture ? Color.clear : cellColor(intensity: intensity))
            .frame(height: 14)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(themeManager.primary.opacity(0.5), lineWidth: 1)
                }
            }
            .help(isFuture ? "" : "\(dateFormatter.string(from: date)): \(String(format: "%.1f", hours))h")
    }

    // MARK: - 범례

    private var legend: some View {
        HStack(spacing: Constants.Design.spacingXS) {
            Text("적음")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            ForEach(0...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(cellColor(intensity: level))
                    .frame(width: 12, height: 12)
            }

            Text("많음")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            Text("데이터가 없습니다")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.vertical, Constants.Design.spacingLG)
            Spacer()
        }
    }

    // MARK: - 헬퍼

    /// 표시할 캘린더 날짜 배열 생성 (선택 기간의 첫날~마지막날)
    private var calendarDays: [Date] {
        let calendar = Calendar.current
        guard let firstDate = data.first?.date else {
            return []
        }

        let endDate = calendar.startOfDay(for: Date())

        // 첫 날이 포함된 주의 일요일부터 시작
        let weekday = calendar.component(.weekday, from: firstDate)
        guard let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: firstDate) else {
            return []
        }

        var dates: [Date] = []
        var current = startOfWeek
        while current <= endDate {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        // 마지막 주 채우기 (토요일까지)
        let remainder = dates.count % 7
        if remainder > 0 {
            for i in 0..<(7 - remainder) {
                guard let date = calendar.date(byAdding: .day, value: i + 1, to: endDate) else { break }
                dates.append(date)
            }
        }

        return dates
    }

    private func hoursForDate(_ date: Date) -> Double {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        return dataMap[day] ?? 0
    }

    private var dataMap: [Date: Double] {
        Dictionary(uniqueKeysWithValues: data.map { ($0.date, $0.focusHours) })
    }

    /// 0~4 강도 레벨
    private func intensityLevel(hours: Double) -> Int {
        switch hours {
        case ..<0.01: return 0
        case ..<1: return 1
        case ..<2: return 2
        case ..<4: return 3
        default: return 4
        }
    }

    private func cellColor(intensity: Int) -> Color {
        switch intensity {
        case 0: return Color.secondary.opacity(0.08)
        case 1: return themeManager.primary.opacity(0.25)
        case 2: return themeManager.primary.opacity(0.5)
        case 3: return themeManager.primary.opacity(0.75)
        default: return themeManager.primary
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "M/d (E)"
        return f
    }
}

#Preview {
    HeatmapView(data: [
        HeatmapEntry(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, focusHours: 2.5),
        HeatmapEntry(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, focusHours: 0.5),
        HeatmapEntry(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, focusHours: 4.0),
        HeatmapEntry(date: Date(), focusHours: 1.0),
    ])
    .environment(ThemeManager.shared)
    .frame(width: 400)
    .padding()
}
