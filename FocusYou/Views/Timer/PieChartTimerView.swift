import SwiftUI

// MARK: - 파이차트 타이머 (v0.5 리디자인)
// 글로우 링 + AngularGradient + 끝점 도트 + 라운드 텍스트

struct PieChartTimerView: View {
    @Environment(ThemeManager.self) private var themeManager

    let progress: Double
    let remainingTimeText: String
    let isPaused: Bool
    let activeColor: Color

    @State private var pausePulse = false

    var body: some View {
        ZStack {
            outerGlow
            backgroundTrack
            progressArc
            if clampedProgress > 0.01 { endPointDot }
            centerContent
        }
        .frame(width: 190, height: 190)
        .opacity(isPaused ? (pausePulse ? 0.6 : 0.85) : 1.0)
        .animation(
            isPaused
                ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                : .easeInOut(duration: 0.3),
            value: isPaused
        )
        .onChange(of: isPaused) { _, newValue in
            pausePulse = newValue
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("남은 시간 \(remainingTimeText)")
    }

    // MARK: - 레이어

    /// 1) 외곽 글로우 링 — 넓고 희미한 후광
    private var outerGlow: some View {
        Circle()
            .stroke(
                activeColor.opacity(isPaused ? 0.03 : 0.06),
                lineWidth: 36
            )
    }

    /// 2) 배경 트랙 — 얇은 가이드 원
    private var backgroundTrack: some View {
        Circle()
            .stroke(Color.secondary.opacity(0.1), lineWidth: 8)
    }

    /// 3) 진행 아크 — AngularGradient로 투명→진한색
    private var progressArc: some View {
        Circle()
            .trim(from: 0, to: clampedProgress)
            .stroke(
                AngularGradient(
                    colors: [
                        activeColor.opacity(0.3),
                        activeColor.opacity(0.6),
                        activeColor,
                    ],
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360 * clampedProgress)
                ),
                style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(.easeInOut(duration: 0.3), value: progress)
    }

    /// 4) 끝점 글로우 도트
    private var endPointDot: some View {
        let angle = Angle.degrees(-90 + 360 * clampedProgress)
        let radius: CGFloat = (190 - 8) / 2
        let x = radius * cos(CGFloat(angle.radians))
        let y = radius * sin(CGFloat(angle.radians))

        return Circle()
            .fill(activeColor)
            .frame(width: 12, height: 12)
            .shadow(color: activeColor.opacity(0.5), radius: 6)
            .offset(x: x, y: y)
    }

    /// 5) 가운데 시간 텍스트
    private var centerContent: some View {
        VStack(spacing: 2) {
            Text(remainingTimeText)
                .font(.system(size: 32, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    isPaused ? themeManager.textSecondary : themeManager.textPrimary
                )

            Text("남은 시간")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var clampedProgress: Double {
        max(0, min(progress, 1))
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
