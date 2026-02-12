import Foundation
import os

// MARK: - DNS 캐시 관리자
// hosts 파일 변경 후 DNS 캐시를 플러시하여 즉시 반영

actor DNSManager {
    static let shared = DNSManager()

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "DNS"
    )

    /// DNS 캐시 플러시
    /// dscacheutil -flushcache + sudo killall -HUP mDNSResponder
    func flushDNSCache() async throws {
        logger.info("DNS 캐시 플러시 시작")

        let script = "dscacheutil -flushcache && killall -HUP mDNSResponder"

        do {
            _ = try await PrivilegedHelper.shared.executeAsAdmin(script: script)
            logger.info("DNS 캐시 플러시 완료")
        } catch {
            logger.error("DNS 캐시 플러시 실패: \(error.localizedDescription)")
            throw FocusYouError.dnsFlushFailed
        }
    }
}
