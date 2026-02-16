import Foundation
import UserNotifications
import os

// MARK: - 알림 서비스
// 타이머 완료, 앱 차단 등의 시스템 알림 관리

protocol NotificationServicing: Sendable {
    func requestPermission() async -> Bool
    func sendTimerCompleted(duration: TimeInterval) async
    func sendAppBlocked(appName: String) async
    func sendBlockingDeactivated() async
    func sendPomodoroPhaseStarted(phaseTitle: String, cycleText: String) async
}

actor NotificationService {
    static let shared = NotificationService()

    private let defaults = UserDefaults.standard

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "Notification"
    )

    private init() {}

    // MARK: - 권한

    /// 알림 권한 요청
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            logger.info("알림 권한 요청 결과: \(granted)")
            return granted
        } catch {
            logger.error("알림 권한 요청 실패: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 알림 발송

    /// 타이머 완료 알림
    func sendTimerCompleted(duration: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification_timer_complete_title")
        content.body = String(localized: "notification_timer_complete_body \(duration.formattedAsReadable)")
        content.sound = isCompletionSoundEnabled() ? .default : nil

        await send(content: content, identifier: "timer-completed")
    }

    /// 차단된 앱 알림
    func sendAppBlocked(appName: String) async {
        guard shouldSendBlockingEventNotification else {
            logger.debug("차단 앱 알림 비활성화로 발송 건너뜀")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification_app_blocked_title")

        // 명언 설정 ON이면 본문에 명언 추가
        if isMotivationQuotesEnabled(), let quoteText = QuoteService.randomQuoteText() {
            content.body = String(localized: "notification_app_blocked_body \(appName)") + "\n\(quoteText)"
        } else {
            content.body = String(localized: "notification_app_blocked_body \(appName)")
        }
        content.sound = nil

        await send(content: content, identifier: "app-blocked-\(appName)")
    }

    /// 차단 해제 알림
    func sendBlockingDeactivated() async {
        guard shouldSendBlockingEventNotification else {
            logger.debug("차단 해제 알림 비활성화로 발송 건너뜀")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification_blocking_deactivated_title")
        content.body = String(localized: "notification_blocking_deactivated_body")
        content.sound = nil

        await send(content: content, identifier: "blocking-deactivated")
    }

    /// 뽀모도로 페이즈 전환 알림
    func sendPomodoroPhaseStarted(phaseTitle: String, cycleText: String) async {
        guard shouldSendBlockingEventNotification else {
            logger.debug("뽀모도로 페이즈 알림 비활성화로 발송 건너뜀")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification_pomodoro_phase_title")
        content.body = String(localized: "notification_pomodoro_phase_body \(phaseTitle) \(cycleText)")
        content.sound = nil

        await send(content: content, identifier: "pomodoro-phase-\(UUID().uuidString)")
    }

    /// 스트레칭 알림 (v1.5 번아웃 방지)
    func sendStretchReminder() async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification_stretch_title")
        content.body = String(localized: "notification_stretch_body")
        content.sound = .default

        await send(content: content, identifier: "stretch-reminder")
    }

    // MARK: - Private

    private func send(content: UNMutableNotificationContent, identifier: String) async {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // 즉시 발송
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.debug("알림 발송: \(identifier)")
        } catch {
            logger.error("알림 발송 실패: \(error.localizedDescription)")
        }
    }

    private func boolSetting(for key: String, default defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }

    private var shouldSendBlockingEventNotification: Bool {
        isBlockingEventNotificationEnabled()
    }

    // MARK: - Internal (Test)

    func isCompletionSoundEnabled() -> Bool {
        boolSetting(
            for: Constants.Settings.playCompletionSoundKey,
            default: Constants.Settings.playCompletionSoundDefault
        )
    }

    func isBlockingEventNotificationEnabled() -> Bool {
        boolSetting(
            for: Constants.Settings.showBlockedAppNotificationKey,
            default: Constants.Settings.showBlockedAppNotificationDefault
        )
    }

    func isMotivationQuotesEnabled() -> Bool {
        boolSetting(
            for: Constants.Settings.showMotivationQuotesKey,
            default: Constants.Settings.showMotivationQuotesDefault
        )
    }
}

extension NotificationService: NotificationServicing {}
