import Foundation
import SwiftData

// MARK: - 차단 웹사이트 모델

@Model
final class BlockedSite {
    /// 도메인 (예: "facebook.com")
    var domain: String

    /// 카테고리 (예: "SNS", "뉴스")
    var category: String?

    /// 차단 활성 여부 (개별 토글)
    var isEnabled: Bool

    /// 생성 일시
    var createdAt: Date

    /// 소속 프로필. ProfileBootstrapper가 기본 프로필을 할당하므로 런타임에 nil이 아니어야 하지만,
    /// SwiftData 마이그레이션 호환을 위해 Optional 유지.
    var profile: BlockProfile?

    init(domain: String, category: String? = nil) {
        self.domain = domain.normalizedDomain
        self.category = category
        self.isEnabled = true
        self.createdAt = .now
    }
}
