import WidgetKit
import SwiftUI

// MARK: - 집중 상태 위젯

struct FocusStatusWidget: Widget {
    let kind = "FocusStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusStatusProvider()) { entry in
            FocusStatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("집중 상태")
        .description("현재 집중 상태와 남은 시간을 표시합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Entry

struct FocusStatusEntry: TimelineEntry {
    let date: Date
    let isFocusing: Bool
    let remainingSeconds: Int
    let totalSeconds: Int
    let timerMode: String
    let primaryHex: String
    let accentHex: String
}

// MARK: - Timeline Provider

struct FocusStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusStatusEntry {
        makeEntry(from: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusStatusEntry) -> Void) {
        let data = SharedDataProvider.read()
        completion(makeEntry(from: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusStatusEntry>) -> Void) {
        let data = SharedDataProvider.read()
        let entry = makeEntry(from: data)

        // 집중 중이면 1분 간격, 아니면 15분 간격
        let refreshInterval: TimeInterval = (data?.isFocusing == true) ? 60 : 900
        let nextUpdate = Date().addingTimeInterval(refreshInterval)

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func makeEntry(from data: SharedFocusData?) -> FocusStatusEntry {
        let data = data ?? SharedDataProvider.placeholder
        return FocusStatusEntry(
            date: .now,
            isFocusing: data.isFocusing,
            remainingSeconds: data.remainingSeconds,
            totalSeconds: data.totalSeconds,
            timerMode: data.timerMode,
            primaryHex: data.themePrimaryHex,
            accentHex: data.themeAccentHex
        )
    }
}

// MARK: - Widget View

struct FocusStatusWidgetView: View {
    let entry: FocusStatusEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - Small

    private var smallView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(hex: entry.primaryHex).opacity(0.2), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color(hex: entry.primaryHex),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Image(systemName: entry.isFocusing ? "brain.head.profile" : "shield.fill")
                        .font(.title2)
                        .foregroundStyle(Color(hex: entry.primaryHex))

                    if entry.isFocusing {
                        Text(formattedTime)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color(hex: entry.primaryHex))
                    }
                }
            }
            .frame(width: 80, height: 80)

            Text(entry.isFocusing ? "집중 중" : "대기 중")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Medium

    private var mediumView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(hex: entry.primaryHex).opacity(0.2), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color(hex: entry.primaryHex),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Image(systemName: entry.isFocusing ? "brain.head.profile" : "shield.fill")
                    .font(.title2)
                    .foregroundStyle(Color(hex: entry.primaryHex))
            }
            .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.isFocusing ? "집중 중" : "Focus You")
                    .font(.headline)
                    .foregroundStyle(Color(hex: entry.primaryHex))

                if entry.isFocusing {
                    Text("남은 시간: \(formattedTime)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Text(modeDisplayName)
                        .font(.caption)
                        .foregroundStyle(Color(hex: entry.accentHex))
                } else {
                    Text("집중할 준비가 되셨나요?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private var progress: Double {
        guard entry.totalSeconds > 0 else { return 0 }
        let elapsed = entry.totalSeconds - entry.remainingSeconds
        return Double(elapsed) / Double(entry.totalSeconds)
    }

    private var formattedTime: String {
        let minutes = entry.remainingSeconds / 60
        let seconds = entry.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var modeDisplayName: String {
        switch entry.timerMode {
        case "pomodoro": return String(localized: "widget_mode_pomodoro")
        case "flowmodoro": return String(localized: "widget_mode_flowmodoro")
        default: return String(localized: "widget_mode_free")
        }
    }
}

// MARK: - Color+Hex (위젯 전용)

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

#Preview(as: .systemSmall) {
    FocusStatusWidget()
} timeline: {
    FocusStatusEntry(
        date: .now, isFocusing: true,
        remainingSeconds: 1500, totalSeconds: 1500,
        timerMode: "free", primaryHex: "#E63946", accentHex: "#2A9D8F"
    )
    FocusStatusEntry(
        date: .now, isFocusing: false,
        remainingSeconds: 0, totalSeconds: 0,
        timerMode: "free", primaryHex: "#E63946", accentHex: "#2A9D8F"
    )
}
