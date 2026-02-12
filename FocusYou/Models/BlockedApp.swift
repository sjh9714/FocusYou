import Foundation
import SwiftData

// MARK: - 차단 앱 모델

@Model
final class BlockedApp {
    /// 번들 ID (예: "com.tinyspeck.slackmacgap")
    var bundleId: String

    /// 앱 이름 (예: "Slack")
    var name: String

    /// 카테고리 (예: "SNS", "메신저")
    var category: String?

    /// 차단 활성 여부 (개별 토글)
    var isEnabled: Bool

    /// 생성 일시
    var createdAt: Date

    /// 소속 프로필
    var profile: BlockProfile?

    init(bundleId: String, name: String, category: String? = nil) {
        self.bundleId = bundleId
        self.name = name
        self.category = category
        self.isEnabled = true
        self.createdAt = .now
    }
}
