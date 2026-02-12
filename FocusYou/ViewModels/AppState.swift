import SwiftUI
import SwiftData
import os

// MARK: - 전역 앱 상태
// 타이머, 차단, 세션을 통합 관리하는 중앙 상태

@MainActor
@Observable
final class AppState {

    // MARK: - 집중 상태

    enum FocusState {
        case idle
        case focusing
        case paused
        case completed
    }

    private(set) var focusState: FocusState = .idle
    private(set) var isBlockingActive = false

    /// 현재 세션
    private(set) var currentSession: FocusSession?

    /// 에러 메시지 (alert용)
    var errorMessage: String?
    var showError = false
    var canRetryBlockingDeactivation = false

    // MARK: - 타이머

    let timer = FreeTimer()

    // MARK: - 메뉴바

    var menuBarIcon: String {
        isBlockingActive ? Constants.UI.menuBarIconActive : Constants.UI.menuBarIconIdle
    }

    // MARK: - Private

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "AppState"
    )

    // MARK: - 초기화

    init() {
        // 타이머 완료 콜백 설정
        timer.onComplete = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleTimerComplete()
            }
        }

        // 알림 권한 요청
        Task {
            _ = await NotificationService.shared.requestPermission()
        }

        // 앱 시작 시 긴급 정리 확인
        Task { @MainActor [weak self] in
            guard let self else { return }
            await BlockingCoordinator.shared.emergencyCleanup()

            if case .error(let cleanupError) = await BlockingCoordinator.shared.state {
                self.logger.error("앱 시작 시 긴급 정리 실패: \(cleanupError.localizedDescription)")
                self.presentError(
                    "앱 시작 시 차단 복구에 실패했습니다. \(cleanupError.localizedDescription)",
                    canRetryDeactivation: true
                )
            }
        }
    }

    // MARK: - 집중 세션 시작

    func startFocusSession(
        duration: TimeInterval,
        sites: [BlockedSite],
        apps: [BlockedApp],
        modelContext: ModelContext
    ) async {
        guard focusState == .idle else {
            logger.warning("세션 시작 실패: 이미 진행 중")
            return
        }

        logger.info("집중 세션 시작: \(Int(duration))초")

        do {
            // 1. 차단 활성화
            let enabledDomains = sites.filter(\.isEnabled).map(\.domain)
            let enabledBundleIds = apps.filter(\.isEnabled).map(\.bundleId)

            logger.info("차단 대상: 사이트 \(enabledDomains.count)개, 앱 \(enabledBundleIds.count)개")

            if enabledDomains.isEmpty && enabledBundleIds.isEmpty {
                logger.warning("차단 목록이 비어있음 — 차단 없이 타이머만 시작")
            }

            try await BlockingCoordinator.shared.activateBlocking(
                domains: enabledDomains,
                appBundleIds: enabledBundleIds
            )
            isBlockingActive = !enabledDomains.isEmpty || !enabledBundleIds.isEmpty

            // 2. 타이머 시작
            timer.start(duration: duration)

            // 3. 세션 기록 생성
            let session = FocusSession(
                timerMode: "free",
                plannedDuration: Int(duration)
            )
            modelContext.insert(session)
            currentSession = session

            // 4. 상태 전환
            focusState = .focusing
            logger.info("집중 세션 시작 완료")

        } catch let error as FocusYouError {
            logger.error("세션 시작 실패: \(error.localizedDescription)")

            if case .authorizationCancelled = error {
                // 사용자가 비밀번호 입력을 취소한 경우 조용히 처리
                return
            }

            presentError(error.localizedDescription)
        } catch {
            logger.error("세션 시작 실패 (알 수 없는 에러): \(error.localizedDescription)")
            presentError(error.localizedDescription)
        }
    }

    // MARK: - 일시정지 / 재개

    func pauseSession() {
        guard focusState == .focusing else { return }
        timer.pause()
        focusState = .paused
        logger.info("세션 일시정지")
    }

    func resumeSession() {
        guard focusState == .paused else { return }
        timer.resume()
        focusState = .focusing
        logger.info("세션 재개")
    }

    // MARK: - 세션 중지 (취소)

    func stopSession(modelContext: ModelContext) async {
        guard focusState == .focusing || focusState == .paused else { return }
        logger.info("세션 중지 (사용자 취소)")
        let wasBlockingActive = isBlockingActive

        // 타이머 정지
        let elapsed = Int(timer.elapsedTime)
        timer.stop()

        // 차단 해제
        do {
            try await BlockingCoordinator.shared.deactivateBlocking()
            if wasBlockingActive {
                await NotificationService.shared.sendBlockingDeactivated()
            }
            isBlockingActive = false
        } catch {
            logger.error("차단 해제 실패: \(error.localizedDescription)")
            isBlockingActive = wasBlockingActive
            presentError(
                "차단 해제에 실패했습니다. \(error.localizedDescription)",
                canRetryDeactivation: true
            )
        }

        // 세션 기록 업데이트
        currentSession?.cancel(actualDuration: elapsed)
        currentSession = nil

        focusState = .idle
    }

    // MARK: - 타이머 완료 처리

    private func handleTimerComplete() async {
        logger.info("타이머 완료 → 세션 종료 처리")
        let wasBlockingActive = isBlockingActive

        // 1. 완료 알림
        await NotificationService.shared.sendTimerCompleted(
            duration: timer.totalDuration
        )

        // 2. 차단 해제
        do {
            try await BlockingCoordinator.shared.deactivateBlocking()
            if wasBlockingActive {
                await NotificationService.shared.sendBlockingDeactivated()
            }
            isBlockingActive = false
        } catch {
            logger.error("타이머 완료 후 차단 해제 실패: \(error.localizedDescription)")
            isBlockingActive = wasBlockingActive
            presentError(
                "타이머 완료 후 차단 해제에 실패했습니다. \(error.localizedDescription)",
                canRetryDeactivation: true
            )
        }

        // 3. 세션 기록
        currentSession?.complete(actualDuration: Int(timer.totalDuration))
        currentSession = nil

        // 4. 상태 전환
        focusState = .completed
    }

    /// 완료 상태에서 유휴로 복귀
    func resetToIdle() {
        timer.reset()
        focusState = .idle
    }

    /// 차단 해제 재시도 (alert의 재시도 버튼에서 호출)
    func retryBlockingDeactivation() async {
        guard canRetryBlockingDeactivation else { return }

        do {
            try await BlockingCoordinator.shared.deactivateBlocking()
            if isBlockingActive {
                await NotificationService.shared.sendBlockingDeactivated()
            }
            isBlockingActive = false
            canRetryBlockingDeactivation = false
            errorMessage = nil
        } catch {
            logger.error("차단 해제 재시도 실패: \(error.localizedDescription)")
            isBlockingActive = true
            presentError(
                "차단 해제 재시도에 실패했습니다. \(error.localizedDescription)",
                canRetryDeactivation: true
            )
        }
    }

    /// 공통 에러 표시 헬퍼
    private func presentError(
        _ message: String,
        canRetryDeactivation: Bool = false
    ) {
        errorMessage = message
        canRetryBlockingDeactivation = canRetryDeactivation
        showError = true
    }
}
