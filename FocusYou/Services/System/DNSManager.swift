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
        #if APPSTORE
        throw FocusYouError.dnsFlushFailed
        #else
        logger.info("DNS 캐시 플러시 시작")

        // macOS 26+: HUP 후 SIGTERM으로 mDNSResponder 완전 재시작 (launchd 자동 복구)
        let script = "dscacheutil -flushcache && killall -HUP mDNSResponder && sleep 1 && (killall mDNSResponder 2>/dev/null || true)"

        do {
            _ = try await PrivilegedHelper.shared.executeAsAdmin(script: script)
            logger.info("DNS 캐시 플러시 완료")
        } catch {
            logger.error("DNS 캐시 플러시 실패: \(error.localizedDescription)")
            throw FocusYouError.dnsFlushFailed
        }
        #endif
    }
}
