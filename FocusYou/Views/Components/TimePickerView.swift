import SwiftUI

// MARK: - 시간 선택 컴포넌트

struct TimePickerView: View {
    @Binding var minutes: Double
    let range: ClosedRange<Double>

    init(
        minutes: Binding<Double>,
        range: ClosedRange<Double> = 1...240
    ) {
        self._minutes = minutes
        self.range = range
    }

    var body: some View {
        VStack(spacing: 4) {
            Slider(value: $minutes, in: range, step: 1) {
                Text("시간 설정")
            }
            .tint(ThemeManager.shared.primary)

            HStack {
                Text("\(Int(range.lowerBound))분")
                Spacer()
                Text("\(Int(minutes))분")
                    .bold()
                Spacer()
                Text("\(Int(range.upperBound))분")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityLabel("타이머 시간 설정: \(Int(minutes))분")
    }
}

#Preview {
    TimePickerView(minutes: .constant(25))
        .padding()
        .frame(width: 300)
}
