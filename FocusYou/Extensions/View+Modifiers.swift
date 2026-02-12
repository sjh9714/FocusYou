import SwiftUI

// MARK: - 공통 View 모디파이어

extension View {
    /// 카드 스타일 배경 적용
    func cardStyle() -> some View {
        self
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    /// 섹션 헤더 스타일
    func sectionHeader() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
