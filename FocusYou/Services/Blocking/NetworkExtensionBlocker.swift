import Foundation
@preconcurrency import NetworkExtension
import SystemExtensions
import os

// MARK: - Network Extension 기반 웹사이트 차단 (v2.0)

/// NEFilterDataProvider를 통한 App Store 호환 웹사이트 차단
/// HostsFileBlocker의 대안으로, 관리자 권한 없이 동작합니다.
actor NetworkExtensionBlocker: WebsiteBlocker {

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "NetworkExtensionBlocker"
    )

    /// System Extension 설치 완료 여부
    private var isExtensionInstalled = false

    /// System Extension delegate 강참조 (콜백까지 유지)
    private var extensionDelegate: SystemExtensionDelegate?

    // MARK: - WebsiteBlocker

    func activate(domains: [String]) async throws {
        logger.info("NE 차단 활성화: \(domains.count)개 도메인")

        // 1. 공유 데이터에 도메인 목록 쓰기
        SharedBlockingData.write(SharedBlockingDomains(
            domains: domains,
            isActive: true,
            updatedAt: .now
        ))

        // 2. System Extension 설치 확인/요청
        if !isExtensionInstalled {
            try await installSystemExtension()
        }

        // 3. NEFilterManager 활성화
        try await enableFilter()
    }

    func deactivate() async throws {
        logger.info("NE 차단 해제")

        // 1. 공유 데이터 삭제
        SharedBlockingData.clear()

        // 2. NEFilterManager 비활성화
        try await disableFilter()
    }

    func isActive() async -> Bool {
        await withCheckedContinuation { continuation in
            NEFilterManager.shared().loadFromPreferences { error in
                if let error {
                    self.logger.error("NEFilterManager 로드 실패: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: NEFilterManager.shared().isEnabled)
            }
        }
    }

    // MARK: - System Extension 설치

    /// System Extension 활성화 요청
    /// 최초 실행 시 macOS가 사용자에게 승인 다이얼로그를 표시합니다.
    private func installSystemExtension() async throws {
        logger.info("System Extension 설치 요청")

        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: Constants.NetworkExtension.extensionBundleID,
            queue: .main
        )

        let delegate = SystemExtensionDelegate()
        self.extensionDelegate = delegate  // 콜백까지 강참조 유지
        request.delegate = delegate

        OSSystemExtensionManager.shared.submitRequest(request)

        // delegate에서 결과 대기
        let result = await delegate.waitForResult()
        self.extensionDelegate = nil  // 완료 후 해제

        switch result {
        case .completed:
            isExtensionInstalled = true
            logger.info("System Extension 설치 완료")
        case .willCompleteAfterReboot:
            isExtensionInstalled = true
            logger.info("System Extension 재부팅 후 완료 예정")
        case .failed(let error):
            logger.error("System Extension 설치 실패: \(error.localizedDescription, privacy: .public)")
            throw FocusYouError.networkExtensionActivationFailed
        }
    }

    // MARK: - NEFilterManager

    /// 필터 활성화
    private func enableFilter() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NEFilterManager.shared().loadFromPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let manager = NEFilterManager.shared()
                if manager.providerConfiguration == nil {
                    let config = NEFilterProviderConfiguration()
                    config.filterSockets = true
                    manager.providerConfiguration = config
                }

                manager.isEnabled = true

                manager.saveToPreferences { saveError in
                    if let saveError {
                        self.logger.error("NEFilterManager 저장 실패: \(saveError.localizedDescription)")
                        continuation.resume(throwing: FocusYouError.networkExtensionActivationFailed)
                        return
                    }

                    // 저장 후 재로드하여 활성 상태 검증
                    NEFilterManager.shared().loadFromPreferences { verifyError in
                        if let verifyError {
                            self.logger.error("NEFilterManager 검증 실패: \(verifyError.localizedDescription)")
                            continuation.resume(throwing: FocusYouError.networkExtensionActivationFailed)
                            return
                        }

                        guard NEFilterManager.shared().isEnabled else {
                            self.logger.error("NEFilterManager 저장 후 비활성 — 활성화 실패")
                            continuation.resume(throwing: FocusYouError.networkExtensionActivationFailed)
                            return
                        }

                        self.logger.info("NEFilterManager 활성화 검증 완료")
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// 필터 비활성화
    private func disableFilter() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NEFilterManager.shared().loadFromPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let manager = NEFilterManager.shared()
                manager.isEnabled = false

                manager.saveToPreferences { saveError in
                    if let saveError {
                        self.logger.error("NEFilterManager 비활성화 실패: \(saveError.localizedDescription)")
                        continuation.resume(throwing: FocusYouError.networkExtensionDeactivationFailed)
                        return
                    }

                    // 저장 후 재로드하여 비활성 상태 검증
                    NEFilterManager.shared().loadFromPreferences { verifyError in
                        if let verifyError {
                            self.logger.error("NEFilterManager 비활성화 검증 실패: \(verifyError.localizedDescription)")
                            continuation.resume(throwing: FocusYouError.networkExtensionDeactivationFailed)
                            return
                        }

                        if NEFilterManager.shared().isEnabled {
                            self.logger.error("NEFilterManager 저장 후 여전히 활성 — 비활성화 실패")
                            continuation.resume(throwing: FocusYouError.networkExtensionDeactivationFailed)
                            return
                        }

                        self.logger.info("NEFilterManager 비활성화 검증 완료")
                        continuation.resume()
                    }
                }
            }
        }
    }
}

// MARK: - System Extension Delegate

/// OSSystemExtensionRequest 결과를 async/await로 브릿지
private final class SystemExtensionDelegate: NSObject, OSSystemExtensionRequestDelegate, @unchecked Sendable {

    enum Result {
        case completed
        case willCompleteAfterReboot
        case failed(Error)
    }

    private var continuation: CheckedContinuation<Result, Never>?

    func waitForResult() async -> Result {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        guard let continuation else { return }  // 이미 완료됨
        self.continuation = nil  // 먼저 nil 처리 (이중 resume 방지)
        switch result {
        case .completed:
            continuation.resume(returning: .completed)
        case .willCompleteAfterReboot:
            continuation.resume(returning: .willCompleteAfterReboot)
        @unknown default:
            continuation.resume(returning: .completed)
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        guard let continuation else { return }  // 이미 완료됨
        self.continuation = nil
        continuation.resume(returning: .failed(error))
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        // macOS가 사용자에게 시스템 설정에서 승인하라는 안내를 표시
        // 앱에서는 별도 처리 불필요
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }
}
