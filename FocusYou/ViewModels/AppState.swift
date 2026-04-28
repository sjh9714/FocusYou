import Foundation
import SwiftData
import os

// MARK: - 전역 앱 상태
// 타이머, 차단, 세션을 통합 관리하는 중앙 상태

@MainActor
@Observable
final class AppState {

    /// AppIntents, Widget 등 외부에서 접근하기 위한 약한 참조
    static weak var shared: AppState?

    // MARK: - 집중 상태

    enum FocusState: Sendable {
        case idle
        case focusing
        case paused
        case completed
    }

    enum TimerMode: String, Sendable {
        case free
        case pomodoro
        case flowmodoro
    }

    var focusState: FocusState = .idle
    var isBlockingActive = false
    var timerMode: TimerMode = .free
    var currentPomodoroPhase: PomodoroEngine.Phase?
    var pomodoroCycleProgressText = ""
    var activeProfileID: PersistentIdentifier?
    var lastCompletedMode: TimerMode = .free
    var lastCompletedFocusDuration: TimeInterval = 0
    var lastCompletedPomodoroCycles = 0
    var lastCompletedPomodoroBreakDuration: TimeInterval = 0
    var lastCompletedFlowmodoroBreakDuration: TimeInterval = 0
    var lastCompletedStreakInfo: StreakCalculator.StreakInfo?

    /// 완료된 세션 (회고 저장용, resetToIdle 시 nil)
    var completedSession: FocusSession?

    /// 완료된 세션의 의도 (UI 표시용)
    var lastCompletedIntention: String?

    /// 마일스톤 축하 표시 (v1.5)
    var pendingMilestone: Milestone?

    /// 레벨업 축하 표시 (v1.x)
    var pendingLevelUp: Int?

    /// 직전 레벨 (레벨업 감지용, 0 = 초기화 전)
    var previousLevel: Int = 0

    /// 완료 세션에서 획득한 XP
    var lastCompletedXPEarned: Int = 0

    /// 현재 세션
    var currentSession: FocusSession?

    /// 에러 메시지 (alert용)
    var errorMessage: String?
    var showError = false
    var canRetryBlockingDeactivation = false

    /// Private Relay 경고 표시 여부
    var showPrivateRelayWarning = false
    var privateRelayWarningDismissedThisSession = false

    /// 현재 활성 스케줄 이름 (스케줄 자동 시작 시 설정, 중지/완료 시 nil)
    var activeScheduleName: String?

    /// 스케줄 종료 시각 (분 단위, 0~1439). 일시정지 후 재개 시 실시간 조정에 사용
    var scheduleEndMinuteOfDay: Int?

    /// 중간 참여 가능한 진행 중 스케줄 (idle 상태에서 표시)
    var pendingScheduleRejoin: PendingScheduleInfo?

    /// 스케줄 재참여 정보
    struct PendingScheduleInfo: Equatable {
        let scheduleName: String
        let profileID: PersistentIdentifier
        let endMinuteOfDay: Int
        let endTimeFormatted: String
    }

    // MARK: - 취소 강도 (v1.3)

    var sessionStartedAt: Date?
    var currentCancelIntensity: Int = 0
    var currentCancelLockoutMinutes: Int = 0
    var emergencyUnlockCountdown: TimeInterval = 0
    var isEmergencyUnlockActive = false
    var emergencyUnlockTimer: Timer?

    // MARK: - 타이머

    let timer = FreeTimer()
    let pomodoroEngine = PomodoroEngine()
    let flowmodoroEngine = FlowmodoroEngine()
    var currentFlowmodoroPhase: FlowmodoroEngine.PhaseType?
    var accumulatedPomodoroFocusDuration: TimeInterval = 0
    var sessionBlockedDomains: [String] = []
    var sessionBlockedAppBundleIds: [String] = []
    var sessionBlocklistMode: String = "blocklist"

    // MARK: - Dependencies

    let blockingCoordinator: any BlockingCoordinating
    let notificationService: any NotificationServicing
    let timingCalculator: SessionTimingCalculator
    let targetResolver: SessionTargetResolver
    let profileSessionMapper: ProfileSessionMapper
    let progressEvaluator: SessionProgressEvaluator
    let sharedDataPublisher: any SharedFocusDataPublishing

    let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "AppState"
    )

    // MARK: - 초기화

    init(
        blockingCoordinator: any BlockingCoordinating = BlockingCoordinator.shared,
        notificationService: any NotificationServicing = NotificationService.shared,
        timingCalculator: SessionTimingCalculator = SessionTimingCalculator(),
        targetResolver: SessionTargetResolver = SessionTargetResolver(),
        profileSessionMapper: ProfileSessionMapper = ProfileSessionMapper(),
        progressEvaluator: SessionProgressEvaluator = SessionProgressEvaluator(),
        sharedDataPublisher: any SharedFocusDataPublishing = SharedFocusDataPublisher(),
        shouldRequestNotificationPermission: Bool = true,
        shouldRunStartupCleanup: Bool = true
    ) {
        self.blockingCoordinator = blockingCoordinator
        self.notificationService = notificationService
        self.timingCalculator = timingCalculator
        self.targetResolver = targetResolver
        self.profileSessionMapper = profileSessionMapper
        self.progressEvaluator = progressEvaluator
        self.sharedDataPublisher = sharedDataPublisher

        // 타이머 완료 콜백 설정
        timer.onComplete = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleTimerComplete()
            }
        }

        // 알림 권한 요청
        if shouldRequestNotificationPermission {
            Task {
                _ = await notificationService.requestPermission()
            }
        }

        // 앱 시작 시 긴급 정리 + 구독 상태 검증
        if shouldRunStartupCleanup {
            Task { @MainActor [weak self] in
                guard let self else { return }
                await blockingCoordinator.emergencyCleanup()

                if case .error(let cleanupError) = await blockingCoordinator.state {
                    self.logger.error("앱 시작 시 긴급 정리 실패: \(cleanupError.localizedDescription)")
                    self.presentError(
                        String(localized: "error_startup_cleanup_failed \(cleanupError.localizedDescription)"),
                        canRetryDeactivation: true
                    )
                }

                // StoreKit 영수증 재검증 → UserDefaults 캐시와 동기화 (#11)
                await SubscriptionManager.shared.refreshEntitlements()
            }
        }

        // AppIntents, Widget 등 외부 접근용
        Self.shared = self
    }

}
