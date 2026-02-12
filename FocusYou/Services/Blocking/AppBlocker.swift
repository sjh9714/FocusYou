import AppKit
import os

// MARK: - 앱 차단기
// NSWorkspace 알림을 통해 차단된 앱 실행을 감지하고 자동 종료

@MainActor
final class AppBlocker {
    static let shared = AppBlocker()

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "AppBlocker"
    )

    private var blockedBundleIds: Set<String> = []
    private var launchObservation: NSObjectProtocol?
    private var isMonitoring = false

    private init() {}

    // MARK: - Public

    /// 차단 활성화: 실행 중인 차단 대상 앱 종료 + 새 실행 감시
    func activate(bundleIds: [String]) {
        guard !bundleIds.isEmpty else {
            logger.debug("차단할 앱이 없음, 건너뜀")
            return
        }

        blockedBundleIds = Set(bundleIds)
        logger.info("앱 차단 활성화: \(bundleIds.count)개 앱")

        // 이미 실행 중인 차단 대상 앱 종료
        terminateRunningBlockedApps()

        // 새 앱 실행 감시 시작
        startMonitoring()
    }

    /// 차단 해제: 감시 중지
    func deactivate() {
        logger.info("앱 차단 해제")
        blockedBundleIds.removeAll()
        stopMonitoring()
    }

    // MARK: - Private

    /// 현재 실행 중인 차단 대상 앱 종료
    private func terminateRunningBlockedApps() {
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier,
                  blockedBundleIds.contains(bundleId) else {
                continue
            }

            let appName = app.localizedName ?? bundleId
            logger.info("실행 중인 차단 앱 종료: \(appName)")

            if !app.terminate() {
                logger.warning("정상 종료 실패, 강제 종료 시도: \(appName)")
                app.forceTerminate()
            }
        }
    }

    /// NSWorkspace 알림으로 새 앱 실행 감시 시작
    private func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        launchObservation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                  let bundleId = app.bundleIdentifier,
                  self.blockedBundleIds.contains(bundleId) else {
                return
            }

            let appName = app.localizedName ?? bundleId
            self.logger.info("차단된 앱 실행 감지: \(appName)")

            if !app.terminate() {
                self.logger.warning("정상 종료 실패, 강제 종료: \(appName)")
                app.forceTerminate()
            }

            // 차단 알림 발송
            Task {
                await NotificationService.shared.sendAppBlocked(appName: appName)
            }
        }

        logger.debug("앱 실행 감시 시작")
    }

    /// 감시 중지
    private func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        if let observation = launchObservation {
            NSWorkspace.shared.notificationCenter.removeObserver(observation)
            launchObservation = nil
        }

        logger.debug("앱 실행 감시 중지")
    }
}
