import SwiftUI
import SwiftData

// MARK: - 프로필 선택 칩 컴포넌트 (공통)

/// 프로필 목록에서 하나를 선택하는 캡슐 버튼 행
struct ProfileSelectorView: View {
    let profiles: [BlockProfile]
    let activeProfile: BlockProfile?
    let onSelect: (BlockProfile) -> Void

    var body: some View {
        ForEach(profiles) { profile in
            let isActive = profile.persistentModelID == activeProfile?.persistentModelID
            Button {
                onSelect(profile)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: profile.icon)
                        .font(.caption2)
                    Text(profile.name)
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, Constants.Design.spacingSM)
                .padding(.vertical, 5)
                .background(
                    Color(hex: profile.color).opacity(isActive ? 0.2 : 0.08),
                    in: Capsule()
                )
                .foregroundStyle(Color(hex: profile.color))
                .overlay(
                    Capsule()
                        .stroke(
                            Color(hex: profile.color).opacity(isActive ? 0.55 : 0),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    HStack {
        // 프리뷰 데이터가 없으므로 빈 상태
        Text("ProfileSelectorView Preview")
            .foregroundStyle(.secondary)
    }
    .padding()
}
