import Foundation
import os

#if APPSTORE
actor HostsFileBlocker: WebsiteBlocker {
    func activate(domains: [String]) async throws {
        throw FocusYouError.networkExtensionActivationFailed
    }

    func deactivate() async throws {}

    func isActive() async -> Bool {
        false
    }
}
#else

// MARK: - hosts 파일 기반 웹사이트 차단기
// /etc/hosts에 리다이렉트 추가로 웹사이트 차단
// 영구 헬퍼 스크립트를 통해 비밀번호 없이 동작

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

        // 1. hosts 파일 백업 (클린 상태 저장)
        try await hostsFileManager.backupHostsFile()

        // 2. 차단 내용 생성
        let newContent = try await hostsFileManager.buildBlockedContent(domains: domains)

        // 3. 헬퍼 설치 확인 (최초 1회만 비밀번호)
        try await privilegedHelper.ensureHelperInstalled()

        // 4. 헬퍼를 통해 hosts 변경 (비밀번호 불필요)
        do {
            try await privilegedHelper.writeHostsViaHelper(content: newContent)
        } catch {
            // Fallback: 관리자 권한으로 직접 쓰기
            logger.warning("헬퍼 실패, admin fallback: \(error.localizedDescription)")
            try await privilegedHelper.writeFileAsRootAndFlushDNS(
                content: newContent,
                to: Constants.Blocking.hostsFilePath
            )
        }

        logger.info("웹사이트 차단 활성화 완료")
    }

    func deactivate() async throws {
        logger.info("웹사이트 차단 해제 시작")

        let cleanContent = try await hostsFileManager.buildCleanContent()

        // 헬퍼를 통해 비밀번호 없이 해제 시도
        do {
            try await privilegedHelper.writeHostsViaHelper(content: cleanContent)
            logger.info("헬퍼를 통해 웹사이트 차단 해제 완료")
            return
        } catch {
            logger.warning("헬퍼 해제 실패, admin fallback: \(error.localizedDescription)")
        }

        // Fallback: 관리자 권한으로 해제 (비밀번호 필요)
        try await privilegedHelper.writeFileAsRootAndFlushDNS(
            content: cleanContent,
            to: Constants.Blocking.hostsFilePath
        )

        logger.info("웹사이트 차단 해제 완료 (admin fallback)")
    }

    func isActive() async -> Bool {
        await hostsFileManager.hasActiveBlocking()
    }
}
#endif
