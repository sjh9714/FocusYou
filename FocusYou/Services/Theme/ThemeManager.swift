import SwiftUI
import os

// MARK: - 테마 관리자
// v0.1에서는 기본 "Crimson Focus" 테마만 사용
// v0.5에서 10종 테마 + 테마 전환 기능 추가 예정

@Observable
final class ThemeManager: @unchecked Sendable {
    static let shared = ThemeManager()

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "ThemeManager"
    )

    // MARK: - 기본 테마 색상 (Crimson Focus)

    /// 집중 상태 메인 색상 (빨강)
    var primary: Color { Color(hex: "#E63946") }

    /// 휴식 상태 색상 (초록)
    var secondary: Color { Color(hex: "#2D6A4F") }

    /// 강조 색상
    var accent: Color { Color(hex: "#457B9D") }

    /// 텍스트 기본 색상
    var textPrimary: Color { .primary }

    /// 텍스트 보조 색상
    var textSecondary: Color { .secondary }

    /// 배경 색상
    var background: Color { Color(.windowBackgroundColor) }

    /// 시작 버튼 색상
    var startButton: Color { primary }

    /// 정지 버튼 색상
    var stopButton: Color { Color(hex: "#D62828") }

    /// 일시정지 버튼 색상
    var pauseButton: Color { accent }

    /// 프로그레스 바 색상
    var progress: Color { primary }

    /// 완료 색상
    var completed: Color { secondary }

    private init() {
        logger.debug("ThemeManager 초기화: Crimson Focus 테마")
    }
}
