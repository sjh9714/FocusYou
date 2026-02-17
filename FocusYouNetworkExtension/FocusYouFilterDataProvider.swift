import NetworkExtension
import os

// MARK: - NEFilterDataProvider (v2.0 웹사이트 차단)

/// Network Extension 기반 콘텐츠 필터
/// App Groups UserDefaults에서 차단 도메인 목록을 읽고,
/// 매칭되는 네트워크 플로우를 차단합니다.
class FocusYouFilterDataProvider: NEFilterDataProvider {

    private let logger = Logger(
        subsystem: "com.sungjh.focusyou.network-extension",
        category: "Filter"
    )

    /// 캐싱된 차단 도메인 목록 (성능 최적화)
    private var blockedDomains: Set<String> = []

    // MARK: - Lifecycle

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        logger.info("필터 시작")
        loadBlockedDomains()

        // App Groups UserDefaults 변경 감지
        if let defaults = UserDefaults(suiteName: "group.com.sungjh.focusyou") {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(defaultsDidChange),
                name: UserDefaults.didChangeNotification,
                object: defaults
            )
        }

        completionHandler(nil)
    }

    override func stopFilter(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        logger.info("필터 중지: \(String(describing: reason))")
        NotificationCenter.default.removeObserver(self)
        completionHandler()
    }

    // MARK: - Flow 처리

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard let hostname = extractHostname(from: flow) else {
            return .allow()
        }

        if shouldBlock(hostname: hostname) {
            logger.info("차단: \(hostname, privacy: .public)")
            return .drop()
        }

        return .allow()
    }

    // MARK: - Private

    @objc private func defaultsDidChange() {
        loadBlockedDomains()
    }

    /// App Groups에서 차단 도메인 로드
    private func loadBlockedDomains() {
        guard let data = SharedBlockingData.read(),
              data.isActive else {
            blockedDomains = []
            return
        }
        blockedDomains = Set(data.domains.map { $0.lowercased() })
        logger.info("차단 도메인 \(self.blockedDomains.count)개 로드")
    }

    /// NEFilterFlow에서 호스트네임 추출 (macOS)
    private func extractHostname(from flow: NEFilterFlow) -> String? {
        // NEFilterSocketFlow.remoteHostname (macOS 10.15.4+)
        if let socketFlow = flow as? NEFilterSocketFlow,
           let hostname = socketFlow.remoteHostname {
            return hostname.lowercased()
        }

        // URL 기반 폴백 (일부 WebKit 브라우저 플로우)
        if let url = flow.url, let host = url.host {
            return host.lowercased()
        }

        return nil
    }

    /// 호스트네임이 차단 대상인지 확인 (서브도메인 포함)
    private func shouldBlock(hostname: String) -> Bool {
        // 정확히 일치
        if blockedDomains.contains(hostname) {
            return true
        }

        // 서브도메인 매칭: "www.example.com" → "example.com"
        let components = hostname.split(separator: ".")
        if components.count > 2 {
            let baseDomain = components.suffix(2).joined(separator: ".")
            if blockedDomains.contains(baseDomain) {
                return true
            }
        }

        return false
    }
}
