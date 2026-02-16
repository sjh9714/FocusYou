import SwiftUI

// MARK: - 성장 타임라인 뷰 (v1.5)
// 전체 5단계 성장 진행 시각화

struct GrowthView: View {
    let totalHours: Double
    let xpInfo: LevelManager.XPInfo
    @Environment(ThemeManager.self) private var themeManager

    private var currentStage: GrowthStage {
        GrowthManager.currentStage(totalHours: totalHours)
    }

    private var currentProgress: Double {
        GrowthManager.progress(totalHours: totalHours)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Text("성장")
                .font(.headline)

            // 메인 뱃지 + 레벨 뱃지
            HStack(spacing: Constants.Design.spacingMD) {
                GrowthBadgeView(stage: currentStage, progress: currentProgress)

                Spacer()

                LevelBadgeView(xpInfo: xpInfo)
            }

            // XP 진행 바
            VStack(spacing: Constants.Design.spacingXS) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))

                        Capsule()
                            .fill(themeManager.accent)
                            .frame(width: max(4, geometry.size.width * xpInfo.progressInLevel))
                    }
                }
                .frame(height: 6)
                .clipShape(Capsule())

                HStack {
                    Text("\(xpInfo.currentLevelXP) / \(xpInfo.nextLevelXP) XP")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if let remaining = GrowthManager.hoursToNextStage(totalHours: totalHours) {
                        Text(String(localized: "다음 단계까지 \(Int(remaining))시간"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // 단계 타임라인
            HStack(spacing: 0) {
                ForEach(GrowthStage.allCases, id: \.rawValue) { stage in
                    stageIndicator(stage)
                    if stage != .garden {
                        Spacer()
                    }
                }
            }
        }
        .frostedCard()
    }

    private func stageIndicator(_ stage: GrowthStage) -> some View {
        let isReached = currentStage >= stage
        let isCurrent = currentStage == stage

        return VStack(spacing: 4) {
            Text(stage.emoji)
                .font(.system(size: isCurrent ? 20 : 14))
                .opacity(isReached ? 1 : 0.3)
                .scaleEffect(isCurrent ? 1.1 : 1.0)
                .animation(.focusSpring, value: isCurrent)

            Text(stage.name)
                .font(.caption2)
                .foregroundStyle(isReached ? .primary : .tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            let status = isCurrent ? String(localized: "현재") : isReached ? String(localized: "달성") : String(localized: "미달성")
            return String(localized: "\(stage.name) 단계, \(status)")
        }())
    }
}

#Preview {
    VStack(spacing: 16) {
        GrowthView(
            totalHours: 5,
            xpInfo: .init(totalXP: 120, level: 2, currentLevelXP: 70, nextLevelXP: 100, progressInLevel: 0.7)
        )
        GrowthView(
            totalHours: 75,
            xpInfo: .init(totalXP: 2500, level: 8, currentLevelXP: 300, nextLevelXP: 450, progressInLevel: 0.67)
        )
        GrowthView(
            totalHours: 600,
            xpInfo: .init(totalXP: 9500, level: 20, currentLevelXP: 0, nextLevelXP: 525, progressInLevel: 0.0)
        )
    }
    .environment(ThemeManager.shared)
    .padding()
    .frame(width: 400)
}
