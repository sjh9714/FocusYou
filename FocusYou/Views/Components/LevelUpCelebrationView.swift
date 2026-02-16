import SwiftUI

// MARK: - 레벨업 축하 뷰 (v1.x)
// 레벨업 시 오버레이로 표시 — MilestoneCelebrationView 패턴

struct LevelUpCelebrationView: View {
    let newLevel: Int
    let onDismiss: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: Constants.Design.spacingXL) {
            // 레벨 번호 대형 표시
            ZStack {
                Circle()
                    .fill(themeManager.accent.opacity(0.15))
                    .frame(width: 80, height: 80)

                Text("\(newLevel)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.accent)
            }
            .scaleEffect(scale)

            VStack(spacing: Constants.Design.spacingSM) {
                Text("레벨 업!")
                    .font(.title3.bold())
                    .foregroundStyle(themeManager.accent)

                Text("레벨 \(newLevel)에 도달했습니다!")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                withAnimation(.quickEase) {
                    onDismiss()
                }
            } label: {
                Label("확인", systemImage: "checkmark")
            }
            .primaryActionStyle(color: themeManager.accent)
        }
        .padding(Constants.Design.spacingXXL)
        .frostedCard()
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("레벨업! 레벨 \(newLevel) 달성")
    }
}

#Preview {
    LevelUpCelebrationView(newLevel: 5, onDismiss: {})
        .environment(ThemeManager.shared)
        .frame(width: 340)
        .padding()
}
