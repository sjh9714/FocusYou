import UserNotifications
import os

// MARK: - 알림 서비스
// 타이머 완료, 앱 차단 등의 시스템 알림 관리

final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()

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
        content.title = "집중 세션 완료!"
        content.body = "\(duration.formattedAsReadable) 동안 집중했습니다. 잘 했어요!"
        content.sound = .default

        await send(content: content, identifier: "timer-completed")
    }

    /// 차단된 앱 알림
    func sendAppBlocked(appName: String) async {
        let content = UNMutableNotificationContent()
        content.title = "앱 차단됨"
        content.body = "\(appName)이(가) 집중 세션 중 차단되었습니다."
        content.sound = nil

        await send(content: content, identifier: "app-blocked-\(appName)")
    }

    /// 차단 해제 알림
    func sendBlockingDeactivated() async {
        let content = UNMutableNotificationContent()
        content.title = "차단 해제"
        content.body = "모든 웹사이트와 앱 차단이 해제되었습니다."
        content.sound = nil

        await send(content: content, identifier: "blocking-deactivated")
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
}
