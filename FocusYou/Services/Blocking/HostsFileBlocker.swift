import Foundation
import os

// MARK: - hosts 파일 기반 웹사이트 차단기
// /etc/hosts에 127.0.0.1 리다이렉트 추가로 웹사이트 차단

actor HostsFileBlocker: WebsiteBlocker {
    private let hostsFileManager = HostsFileManager.shared
    private let privilegedHelper = PrivilegedHelper.shared

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "HostsFileBlocker"
    )

    func activate(domains: [String]) async throws {
        logger.info("웹사이트 차단 활성화: \(domains.count)개 도메인")

        guard !domains.isEmpty else {
            logger.debug("차단할 도메인이 없음, 건너뜀")
            return
        }

        // 1. hosts 파일 백업
        try await hostsFileManager.backupHostsFile()

        // 2. 차단 내용 생성
        let newContent = try await hostsFileManager.buildBlockedContent(domains: domains)

        // 3. 관리자 권한으로 hosts 파일 쓰기 + DNS 플러시 (단일 admin 호출)
        try await privilegedHelper.writeFileAsRootAndFlushDNS(
            content: newContent,
            to: Constants.Blocking.hostsFilePath
        )

        logger.info("웹사이트 차단 활성화 완료")
    }

    func deactivate() async throws {
        logger.info("웹사이트 차단 해제 시작")

        // 1. 마커 구간 제거된 내용 생성
        let cleanContent = try await hostsFileManager.buildCleanContent()

        // 2. 관리자 권한으로 hosts 파일 쓰기 + DNS 플러시 (단일 admin 호출)
        try await privilegedHelper.writeFileAsRootAndFlushDNS(
            content: cleanContent,
            to: Constants.Blocking.hostsFilePath
        )

        logger.info("웹사이트 차단 해제 완료")
    }

    func isActive() async -> Bool {
        await hostsFileManager.hasActiveBlocking()
    }
}
