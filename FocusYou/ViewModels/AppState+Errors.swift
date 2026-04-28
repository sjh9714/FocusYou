import AppKit
import Foundation

extension AppState {
    /// 차단 해제 재시도 (오류 UI의 재시도 버튼에서 호출)
    func retryBlockingDeactivation() async {
        guard canRetryBlockingDeactivation else { return }

        let success = await safelyDeactivateBlocking(
            shouldNotify: isBlockingActive,
            fallbackBlockingState: true
        ) { String(localized: "error_retry_deactivation_failed \($0)") }

        if success {
            dismissError()
        }
    }

    /// 인라인 에러 표시 닫기
    func dismissError() {
        showError = false
        errorMessage = nil
        canRetryBlockingDeactivation = false
    }

    /// Private Relay 경고를 닫고 이번 세션 내 재표시를 방지합니다.
    func dismissPrivateRelayWarning() {
        showPrivateRelayWarning = false
        privateRelayWarningDismissedThisSession = true
    }

    /// 경고에서 "Private Relay 설정 열기" 선택 시 — 시스템 설정으로 이동
    func openPrivateRelaySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane") {
            NSWorkspace.shared.open(url)
        }
        dismissPrivateRelayWarning()
    }

    /// 공통 에러 표시 헬퍼
    func presentError(
        _ message: String,
        canRetryDeactivation: Bool = false
    ) {
        errorMessage = message
        canRetryBlockingDeactivation = canRetryDeactivation
        showError = true
    }

    /// 차단 해제 공통 헬퍼 — 에러 처리 + 알림 + 상태 복원 패턴 통합
    @discardableResult
    func safelyDeactivateBlocking(
        shouldNotify: Bool,
        fallbackBlockingState: Bool,
        formatError: (String) -> String
    ) async -> Bool {
        do {
            try await blockingCoordinator.deactivateBlocking()
            if shouldNotify {
                await notificationService.sendBlockingDeactivated()
            }
            isBlockingActive = false
            return true
        } catch {
            let desc = error.localizedDescription
            logger.error("차단 해제 실패: \(desc)")
            isBlockingActive = fallbackBlockingState
            presentError(formatError(desc), canRetryDeactivation: true)
            return false
        }
    }
}
