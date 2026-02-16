import SwiftUI

// MARK: - 레벨 뱃지 뷰 (v1.x)
// XP 진행률 링 + 레벨 번호 + XP 텍스트

struct LevelBadgeView: View {
    let xpInfo: LevelManager.XPInfo
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(spacing: Constants.Design.spacingSM) {
            // 원형 진행률 링 + 레벨 번호
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 3)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: xpInfo.progressInLevel)
                    .stroke(
                        themeManager.accent,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                Text("\(xpInfo.level)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Lv. \(xpInfo.level)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("\(xpInfo.totalXP) XP")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "레벨 \(xpInfo.level), 총 \(xpInfo.totalXP) XP, 진행률 \(Int(xpInfo.progressInLevel * 100))%")
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        LevelBadgeView(xpInfo: .init(
            totalXP: 120, level: 2, currentLevelXP: 70, nextLevelXP: 100, progressInLevel: 0.7
        ))
        LevelBadgeView(xpInfo: .init(
            totalXP: 2500, level: 8, currentLevelXP: 300, nextLevelXP: 450, progressInLevel: 0.67
        ))
    }
    .environment(ThemeManager.shared)
    .padding()
}
