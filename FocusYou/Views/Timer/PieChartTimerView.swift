import SwiftUI

// MARK: - 파이차트 타이머 (v0.3)

struct PieChartTimerView: View {
    @Environment(ThemeManager.self) private var themeManager

    let progress: Double
    let remainingTimeText: String
    let isPaused: Bool
    let activeColor: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.16), lineWidth: 14)

            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(
                    isPaused ? themeManager.textSecondary : activeColor,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: progress)

            Text(remainingTimeText)
                .font(.system(size: 36, weight: .light, design: .monospaced))
                .foregroundStyle(
                    isPaused ? themeManager.textSecondary : themeManager.textPrimary
                )
        }
        .frame(width: 190, height: 190)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("남은 시간 \(remainingTimeText)")
    }
}

#Preview {
    PieChartTimerView(
        progress: 0.42,
        remainingTimeText: "14:30",
        isPaused: false,
        activeColor: ThemeManager.shared.primary
    )
    .environment(ThemeManager.shared)
    .padding()
}
