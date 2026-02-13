import SwiftUI

// MARK: - 커스텀 애니메이션

extension Animation {
    /// 집중 앱 기본 스프링 — 자연스러운 바운스
    static let focusSpring = Animation.spring(response: 0.35, dampingFraction: 0.75)
    /// 빠른 이징 — 토글, 작은 전환용
    static let quickEase = Animation.easeInOut(duration: 0.2)
    /// 중간 이징 — 카드 전환, 상태 변경용
    static let mediumEase = Animation.easeInOut(duration: 0.35)
    /// 부드러운 바운스 — 큰 요소 등장용
    static let gentleBounce = Animation.spring(response: 0.5, dampingFraction: 0.7)
}

// MARK: - Frosted Glass 카드

extension View {
    /// 유리질감 카드 — `.ultraThinMaterial` 배경 + 미세 그림자
    func frostedCard(
        cornerRadius: CGFloat = Constants.Design.cornerLG,
        padding: CGFloat = Constants.Design.cardPadding
    ) -> some View {
        self
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    /// 상승 카드 — 불투명 배경 + 더 강한 그림자
    func elevatedCard(
        cornerRadius: CGFloat = Constants.Design.cornerLG
    ) -> some View {
        self
            .padding(Constants.Design.cardPadding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            }
    }

    /// 글로우 보더 — 선택된 요소에 빛나는 테두리
    func glowBorder(
        color: Color,
        cornerRadius: CGFloat = Constants.Design.cornerLG,
        lineWidth: CGFloat = 1.5
    ) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color.opacity(0.5), lineWidth: lineWidth)
            )
            .shadow(color: color.opacity(0.15), radius: 6, x: 0, y: 0)
    }

    /// 소프트 구분선 — 하드 Divider 대체
    func softDivider() -> some View {
        Rectangle()
            .fill(.quaternary)
            .frame(height: 0.5)
    }
}

// MARK: - 버튼 스타일

/// 프라이머리 액션 버튼 — 그라디언트 + 그림자 + 프레스 스케일
struct PrimaryActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
            )
            .foregroundStyle(.white)
            .shadow(color: color.opacity(0.3), radius: configuration.isPressed ? 4 : 8, y: configuration.isPressed ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.focusSpring, value: configuration.isPressed)
    }
}

/// 세컨더리 액션 버튼 — 반투명 배경 + 테두리
struct SecondaryActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                color.opacity(configuration.isPressed ? 0.15 : 0.08),
                in: RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
            )
            .foregroundStyle(color)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                    .stroke(color.opacity(0.15), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.quickEase, value: configuration.isPressed)
    }
}

extension View {
    /// 프라이머리 액션 버튼 스타일 적용
    func primaryActionStyle(color: Color) -> some View {
        self.buttonStyle(PrimaryActionButtonStyle(color: color))
    }

    /// 세컨더리 액션 버튼 스타일 적용
    func secondaryActionStyle(color: Color) -> some View {
        self.buttonStyle(SecondaryActionButtonStyle(color: color))
    }
}

// MARK: - 세그먼트 필 버튼

/// 세그먼트 컨트롤 내 개별 필 — matchedGeometryEffect용
struct SegmentedPill<T: Hashable>: View {
    let title: String
    let tag: T
    @Binding var selection: T
    let namespace: Namespace.ID
    let activeColor: Color

    var body: some View {
        Button {
            withAnimation(.focusSpring) {
                selection = tag
            }
        } label: {
            Text(title)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Capsule())
                .foregroundStyle(selection == tag ? .white : .secondary)
        }
        .buttonStyle(.plain)
        .background {
            if selection == tag {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [activeColor, activeColor.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .matchedGeometryEffect(id: "segment", in: namespace)
                    .shadow(color: activeColor.opacity(0.25), radius: 4, y: 2)
            }
        }
    }
}

// MARK: - 칩 버튼

/// 캡슐 형태의 칩 버튼 (프리셋 선택 등)
struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .contentShape(Capsule())
                .background(
                    isSelected
                        ? color.opacity(0.12)
                        : Color.secondary.opacity(0.06),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? color : .secondary)
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? color.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.quickEase, value: isSelected)
    }
}

// MARK: - 아이콘 뱃지

/// 원형 배경 안의 SF Symbol 아이콘
struct IconBadge: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12), in: Circle())
    }
}

// MARK: - 이전 호환

extension View {
    /// 카드 스타일 배경 적용 (이전 호환)
    func cardStyle() -> some View {
        frostedCard()
    }

    /// 섹션 헤더 스타일
    func sectionHeader() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
