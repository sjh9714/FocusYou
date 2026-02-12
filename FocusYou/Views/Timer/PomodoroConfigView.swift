import SwiftUI

// MARK: - 뽀모도로 설정

struct PomodoroConfigView: View {
    @Binding var configuration: PomodoroConfiguration

    var body: some View {
        VStack(spacing: 10) {
            settingRow(
                title: "집중",
                value: configuration.focusMinutes,
                unit: "분",
                range: Constants.Timer.pomodoroFocusRange
            ) { configuration.focusMinutes = $0 }

            settingRow(
                title: "짧은 휴식",
                value: configuration.shortBreakMinutes,
                unit: "분",
                range: Constants.Timer.pomodoroShortBreakRange
            ) { configuration.shortBreakMinutes = $0 }

            settingRow(
                title: "긴 휴식",
                value: configuration.longBreakMinutes,
                unit: "분",
                range: Constants.Timer.pomodoroLongBreakRange
            ) { configuration.longBreakMinutes = $0 }

            settingRow(
                title: "사이클",
                value: configuration.cycles,
                unit: "회",
                range: Constants.Timer.pomodoroCyclesRange
            ) { configuration.cycles = $0 }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func settingRow(
        title: String,
        value: Int,
        unit: String,
        range: ClosedRange<Int>,
        onChanged: @escaping (Int) -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.callout)
            Spacer()

            Stepper {
                Text("\(value)\(unit)")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            } onIncrement: {
                onChanged(min(range.upperBound, value + 1))
            } onDecrement: {
                onChanged(max(range.lowerBound, value - 1))
            }
            .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PomodoroConfigView(configuration: .constant(.default))
        .padding()
        .frame(width: 320)
}
