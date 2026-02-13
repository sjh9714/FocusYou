import Foundation

// MARK: - 앱 테마 모델

struct AppTheme: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let primaryHex: String
    let secondaryHex: String
    let accentHex: String
    let stopHex: String
    let backgroundHex: String
    /// 다크모드 배경 (optional, 하위호환)
    let backgroundDarkHex: String?

    init(
        id: String,
        name: String,
        primaryHex: String,
        secondaryHex: String,
        accentHex: String,
        stopHex: String,
        backgroundHex: String,
        backgroundDarkHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.primaryHex = primaryHex
        self.secondaryHex = secondaryHex
        self.accentHex = accentHex
        self.stopHex = stopHex
        self.backgroundHex = backgroundHex
        self.backgroundDarkHex = backgroundDarkHex
    }
}
