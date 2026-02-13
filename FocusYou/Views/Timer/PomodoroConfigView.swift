import SwiftUI

// MARK: - 뽀모도로 설정 (v0.5 리디자인)

struct PomodoroConfigView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var configuration: PomodoroConfiguration

    var body: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            settingRow(
                icon: "bolt.fill",
                iconColor: themeManager.primary,
                title: "집중",
                value: configuration.focusMinutes,
                unit: "분",
                range: Constants.Timer.pomodoroFocusRange
            ) { configuration.focusMinutes = $0 }

            settingRow(
                icon: "cup.and.saucer.fill",
                iconColor: themeManager.secondary,
                title: "짧은 휴식",
                value: configuration.shortBreakMinutes,
                unit: "분",
                range: Constants.Timer.pomodoroShortBreakRange
            ) { configuration.shortBreakMinutes = $0 }

            settingRow(
                icon: "clock.fill",
                iconColor: themeManager.accent,
                title: "긴 휴식",
                value: configuration.longBreakMinutes,
                unit: "분",
                range: Constants.Timer.pomodoroLongBreakRange
            ) { configuration.longBreakMinutes = $0 }

            settingRow(
                icon: "arrow.2.squarepath",
                iconColor: themeManager.primary,
                title: "사이클",
                value: configuration.cycles,
                unit: "회",
                range: Constants.Timer.pomodoroCyclesRange
            ) { configuration.cycles = $0 }

            // 사이클 패턴 미리보기
            cycleTimeline
        }
        .frostedCard(cornerRadius: Constants.Design.cornerLG)
    }

    // MARK: - 설정 행

    private func settingRow(
        icon: String,
        iconColor: Color,
        title: String,
        value: Int,
        unit: String,
        range: ClosedRange<Int>,
        onChanged: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            IconBadge(systemName: icon, color: iconColor, size: 28)

            Text(title)
                .font(.callout)

            Spacer()

            Stepper {
                Text("\(value)\(unit)")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(iconColor)
            } onIncrement: {
                onChanged(min(range.upperBound, value + 1))
            } onDecrement: {
                onChanged(max(range.lowerBound, value - 1))
            }
            .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 사이클 타임라인

    private var cycleTimeline: some View {
        HStack(spacing: 4) {
            ForEach(0..<configuration.cycles, id: \.self) { cycle in
                // 집중 도트
                Circle()
                    .fill(themeManager.primary)
                    .frame(width: 8, height: 8)

                // 휴식 도트
                if cycle < configuration.cycles - 1 {
                    Circle()
                        .fill(themeManager.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                } else {
                    // 마지막 사이클 → 긴 휴식
                    RoundedRectangle(cornerRadius: 3)
                        .fill(themeManager.accent.opacity(0.5))
                        .frame(width: 12, height: 6)
                }
            }
        }
        .padding(.top, 4)
        .accessibilityLabel(
            "\(configuration.cycles)사이클: 집중 \(configuration.focusMinutes)분, 휴식 \(configuration.shortBreakMinutes)분"
        )
    }
}

#Preview {
    PomodoroConfigView(configuration: .constant(.default))
        .environment(ThemeManager.shared)
        .padding()
        .frame(width: 320)
}
