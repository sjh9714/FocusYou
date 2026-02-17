import Foundation

// MARK: - 차단 전략 (v2.0)

/// 웹사이트 차단 방식 선택
enum BlockingStrategy: String, CaseIterable, Sendable {
    /// hosts 파일 기반 (관리자 권한 필요, 직접 배포용)
    case hosts
    /// Network Extension 기반 (권한 불필요, App Store 배포용)
    case networkExtension
}

// MARK: - 차단기 팩토리

/// 설정에 따라 적절한 WebsiteBlocker 구현체를 생성
enum WebsiteBlockerFactory {

    /// 현재 설정에 맞는 WebsiteBlocker 생성
    static func create(strategy: BlockingStrategy = currentStrategy()) -> any WebsiteBlocker {
        switch strategy {
        case .hosts:
            HostsFileBlocker()
        case .networkExtension:
            NetworkExtensionBlocker()
        }
    }

    /// UserDefaults에서 현재 차단 전략 읽기
    static func currentStrategy() -> BlockingStrategy {
        let raw = UserDefaults.standard.string(
            forKey: Constants.Settings.blockingStrategyKey
        )
        return BlockingStrategy(rawValue: raw ?? Constants.Settings.blockingStrategyDefault) ?? .hosts
    }
}
