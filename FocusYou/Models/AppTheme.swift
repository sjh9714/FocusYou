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
}
