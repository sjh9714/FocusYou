import Foundation

// MARK: - 웹사이트 차단 프로토콜
// v1: HostsFileBlocker (hosts 파일 기반, 직접 배포용)
// v2: NetworkExtensionBlocker (App Store 배포용, v2.0 예정)

protocol WebsiteBlocker: Sendable {
    /// 차단 활성화 (도메인 목록)
    func activate(domains: [String]) async throws

    /// 차단 해제
    func deactivate() async throws

    /// 차단 활성 상태 확인
    func isActive() async -> Bool
}
