import Foundation
import NetworkExtension
import os

// MARK: - 차단 통합 코디네이터
// 웹사이트 차단 + 앱 차단을 통합 관리하는 중앙 오케스트레이터

protocol BlockingCoordinating: Sendable {
    var state: BlockingCoordinator.State { get async }

    func activateBlocking(
        domains: [String],
        appBundleIds: [String],
        blocklistMode: String
    ) async throws

    func deactivateBlocking() async throws
    func emergencyCleanup() async
}

actor BlockingCoordinator {
    static let shared = BlockingCoordinator(
        websiteBlocker: WebsiteBlockerFactory.create()
    )

    // MARK: - 상태

    enum State: Sendable {
        case idle
        case blocking
        case error(FocusYouError)
    }

    private(set) var state: State = .idle
    private var isWebsiteBlockingActive = false
    private var isAppBlockingActive = false

    // MARK: - Dependencies

    private let websiteBlocker: any WebsiteBlocker
    private let managesSafetyNet: Bool
    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "BlockingCoordinator"
    )

    /// NE 모드에서는 hosts 관련 안전장치 불필요
    private var usesNetworkExtension: Bool {
        websiteBlocker is NetworkExtensionBlocker
    }

    init(
        websiteBlocker: any WebsiteBlocker = HostsFileBlocker(),
        managesSafetyNet: Bool = true
    ) {
        self.websiteBlocker = websiteBlocker
        self.managesSafetyNet = managesSafetyNet
    }

    // MARK: - Public

    /// 차단 활성화 (타이머 시작 시 호출)
    func activateBlocking(
        domains: [String],
        appBundleIds: [String],
        blocklistMode: String = "blocklist"
    ) async throws {
        logger.info("차단 활성화 시작: 사이트 \(domains.count)개, 앱 \(appBundleIds.count)개, 모드: \(blocklistMode)")

        guard !domains.isEmpty || !appBundleIds.isEmpty else {
            logger.info("차단 대상이 없어 활성화 건너뜀")
            isWebsiteBlockingActive = false
            isAppBlockingActive = false
            state = .idle
            return
        }

        isWebsiteBlockingActive = false
        isAppBlockingActive = false

        // 웹사이트 차단
        if !domains.isEmpty || blocklistMode == "allowlist" {
            do {
                if blocklistMode == "allowlist" {
                    // 화이트리스트 모드: top-sites에서 허용 도메인 제외 후 나머지 차단
                    let topSites = loadTopSites()
                    let allowedSet = Set(domains.map { $0.lowercased() })
                    let domainsToBlock = topSites.filter { !allowedSet.contains($0.lowercased()) }
                    if !domainsToBlock.isEmpty {
                        try await websiteBlocker.activate(domains: domainsToBlock)
                        isWebsiteBlockingActive = true
                    }
                } else {
                    try await websiteBlocker.activate(domains: domains)
                    isWebsiteBlockingActive = true
                }
            } catch {
                logger.error("웹사이트 차단 실패: \(error.localizedDescription)")
                let fallbackError: FocusYouError = usesNetworkExtension
                    ? .networkExtensionActivationFailed
                    : .hostsFileWriteFailed
                state = .error(error as? FocusYouError ?? fallbackError)
                throw error
            }
        }

        // 앱 차단 (MainActor에서 실행)
        if !appBundleIds.isEmpty {
            await MainActor.run {
                AppBlocker.shared.activate(bundleIds: appBundleIds)
            }
            isAppBlockingActive = true
        }

        // hosts 모드에서만 안전장치 설치 (NE는 OS가 관리)
        if isWebsiteBlockingActive, managesSafetyNet, !usesNetworkExtension {
            installSafetyNet()
        }

        state = .blocking

        // 앱 디밍 (v1.4)
        if !appBundleIds.isEmpty,
           UserDefaults.standard.bool(forKey: Constants.Settings.enableAppDimmingKey) {
            let opacity = UserDefaults.standard.double(forKey: Constants.Settings.dimmingOpacityKey)
            let effectiveOpacity = opacity > 0 ? opacity : Constants.Settings.dimmingOpacityDefault
            await AppDimmingManager.shared.activate(
                bundleIds: appBundleIds,
                opacity: effectiveOpacity
            )
        }

        logger.info("차단 활성화 완료")
    }

    /// 차단 해제 (타이머 종료/취소 시 호출)
    func deactivateBlocking() async throws {
        logger.info("차단 해제 시작")

        var websiteDeactivationError: Error?
        let websiteIsActive = await websiteBlocker.isActive()
        let shouldDeactivateWebsite = isWebsiteBlockingActive || websiteIsActive

        // 웹사이트 차단 해제 (실제 활성 상태일 때만)
        if shouldDeactivateWebsite {
            do {
                try await websiteBlocker.deactivate()
                isWebsiteBlockingActive = false
            } catch {
                logger.error("웹사이트 차단 해제 실패: \(error.localizedDescription)")
                websiteDeactivationError = error
            }
        } else {
            logger.debug("웹사이트 차단 비활성 상태, hosts 해제 건너뜀")
        }

        // 앱 차단 해제 (idempotent)
        await MainActor.run {
            AppBlocker.shared.deactivate()
        }
        isAppBlockingActive = false

        // 해제 실패 시 안전장치 보존 + 에러 전파
        if let websiteDeactivationError {
            let fallbackError: FocusYouError = usesNetworkExtension
                ? .networkExtensionDeactivationFailed
                : .hostsFileWriteFailed
            state = .error(websiteDeactivationError as? FocusYouError ?? fallbackError)
            throw websiteDeactivationError
        }

        // hosts 모드에서만 안전장치 해제
        if managesSafetyNet, !usesNetworkExtension {
            removeSafetyNet()
        }

        // 앱 디밍 해제 (v1.4)
        await AppDimmingManager.shared.deactivate()

        state = .idle
        logger.info("차단 해제 완료")
    }

    /// 긴급 정리 (앱 시작 시 stale 마커 감지용)
    /// 활성 표시 파일이 있을 때만 실행
    /// 헬퍼를 통해 비밀번호 없이 복구 시도, 실패 시 admin fallback
    func emergencyCleanup() async {
        // NE 모드: NEFilterManager만 비활성화
        if usesNetworkExtension {
            await emergencyCleanupNetworkExtension()
            return
        }

        // hosts 모드: 기존 로직
        await emergencyCleanupHosts()
    }

    /// NE 모드 긴급 정리
    private func emergencyCleanupNetworkExtension() async {
        let neActive = await websiteBlocker.isActive()
        guard neActive else { return }

        logger.warning("NE 긴급 정리: 필터 비활성화")
        do {
            try await websiteBlocker.deactivate()
        } catch {
            logger.error("NE 긴급 정리 실패: \(error.localizedDescription)")
            state = .error(.networkExtensionDeactivationFailed)
            return
        }

        isWebsiteBlockingActive = false
        isAppBlockingActive = false
        state = .idle
    }

    /// hosts 모드 긴급 정리
    private func emergencyCleanupHosts() async {
        let indicatorExists = FileManager.default.fileExists(atPath: Constants.Blocking.activeIndicatorPath)
        let hasActiveBlocking = await HostsFileManager.shared.hasActiveBlocking()
        let backupExists = FileManager.default.fileExists(atPath: Constants.Blocking.hostsBackupPath)
        let launchAgentExists = FileManager.default.fileExists(atPath: Constants.App.launchAgentPath)

        guard indicatorExists || hasActiveBlocking || backupExists || launchAgentExists else {
            return
        }

        logger.warning(
            """
            긴급 정리 수행 (indicator: \(indicatorExists ? "true" : "false"), \
            hosts marker: \(hasActiveBlocking ? "true" : "false"), \
            backup: \(backupExists ? "true" : "false"), \
            launchAgent: \(launchAgentExists ? "true" : "false"))
            """
        )

        // hosts 차단 마커/indicator 없이 안전장치 파일만 남았으면 정리
        if !indicatorExists && !hasActiveBlocking {
            logger.info("긴급 정리: stale 안전장치 파일만 존재, 정리 수행")
            if managesSafetyNet {
                removeSafetyNet()
            }
            isWebsiteBlockingActive = false
            isAppBlockingActive = false
            state = .idle
            return
        }

        // hosts 차단이 없으면 안전장치 파일만 정리
        guard hasActiveBlocking else {
            logger.info("긴급 정리: hosts 차단 없음, 안전장치 파일만 제거")
            if managesSafetyNet {
                removeSafetyNet()
            }
            isWebsiteBlockingActive = false
            isAppBlockingActive = false
            state = .idle
            return
        }

        // 헬퍼를 통해 비밀번호 없이 복구 시도
        var cleanupError: Error?
        do {
            let cleanContent = try await HostsFileManager.shared.buildCleanContent()
            try await PrivilegedHelper.shared.writeHostsViaHelper(content: cleanContent)
            logger.info("긴급 정리: 헬퍼를 통해 복원 완료")
            cleanupError = nil
        } catch {
            logger.warning("헬퍼 복구 실패, admin fallback 시도: \(error.localizedDescription)")
            // Fallback: 기존 방식 (비밀번호 필요)
            do {
                try await websiteBlocker.deactivate()
                logger.info("긴급 정리: hosts 파일 복원 완료 (admin)")
                cleanupError = nil
            } catch {
                logger.error("긴급 정리 실패: \(error.localizedDescription)")
                cleanupError = error
            }
        }

        if let cleanupError {
            state = .error(cleanupError as? FocusYouError ?? .hostsFileWriteFailed)
            logger.error("긴급 정리 미완료 - 안전장치 유지")
            return
        }

        if managesSafetyNet {
            removeSafetyNet()
        }
        isWebsiteBlockingActive = false
        isAppBlockingActive = false
        state = .idle
    }

    // MARK: - 안전장치 (LaunchAgent)

    /// 앱 크래시 시 자동 정리를 위한 LaunchAgent 설치
    private func installSafetyNet() {
        logger.debug("안전장치 설치")

        // 상태 파일 디렉터리 생성
        let stateDirectory = (Constants.Blocking.activeIndicatorPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: stateDirectory,
            withIntermediateDirectories: true
        )

        // 활성 상태 표시 파일 생성
        if !FileManager.default.createFile(
            atPath: Constants.Blocking.activeIndicatorPath,
            contents: Date().description.data(using: .utf8)
        ) {
            logger.error("활성 상태 표시 파일 생성 실패: \(Constants.Blocking.activeIndicatorPath)")
        }

        // LaunchAgent plist 생성
        // 부팅 시 활성 표시 파일이 있으면 헬퍼로 hosts 복구 시도
        let helperPath = Constants.Blocking.helperPath
        let backupPath = Constants.Blocking.hostsBackupPath
        let activeIndicatorPath = Constants.Blocking.activeIndicatorPath
        let launchAgentPath = Constants.App.launchAgentPath
        let quotedHelperPath = shellQuoted(helperPath)
        let quotedBackupPath = shellQuoted(backupPath)
        let quotedActiveIndicatorPath = shellQuoted(activeIndicatorPath)
        let quotedLaunchAgentPath = shellQuoted(launchAgentPath)
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(Constants.App.launchAgentLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/bash</string>
                <string>-c</string>
                <string>if [ -f \(quotedActiveIndicatorPath) ] &amp;&amp; [ -f \(quotedBackupPath) ]; then if sudo -n \(quotedHelperPath) \(quotedBackupPath) 2>/dev/null; then rm -f \(quotedActiveIndicatorPath) \(quotedBackupPath) \(quotedLaunchAgentPath); fi; fi</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """

        let launchAgentDir = (Constants.App.launchAgentPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: launchAgentDir,
            withIntermediateDirectories: true
        )

        try? plistContent.write(
            toFile: Constants.App.launchAgentPath,
            atomically: true,
            encoding: .utf8
        )
    }

    /// 안전장치 제거
    private func removeSafetyNet() {
        logger.debug("안전장치 제거")
        try? FileManager.default.removeItem(atPath: Constants.Blocking.activeIndicatorPath)
        try? FileManager.default.removeItem(atPath: Constants.App.launchAgentPath)
        try? FileManager.default.removeItem(atPath: Constants.Blocking.hostsBackupPath)
    }

    /// 번들에서 top-sites.json 로드 (화이트리스트 모드)
    private func loadTopSites() -> [String] {
        let candidateURLs = [
            Bundle.main.url(forResource: "top-sites", withExtension: "json"),
            Bundle.main.url(forResource: "top-sites", withExtension: "json", subdirectory: "Presets"),
            Bundle.main.url(forResource: "top-sites", withExtension: "json", subdirectory: "Resources/Presets"),
        ]

        guard let url = candidateURLs.compactMap({ $0 }).first,
              let data = try? Data(contentsOf: url),
              let sites = try? JSONDecoder().decode([String].self, from: data) else {
            logger.warning("top-sites.json 로드 실패")
            return []
        }
        return sites
    }

    /// 쉘 명령 인자용 단일 인용부호 이스케이프
    private func shellQuoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\"'\"'")
        return "'\(escaped)'"
    }
}

extension BlockingCoordinator: BlockingCoordinating {}
