import SwiftUI
import SwiftData
import AppKit
import os

@main
struct FocusYouApp: App {
    @State private var appState: AppState
    @State private var settingsViewModel: SettingsViewModel
    @State private var themeManager: ThemeManager
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// 모든 Scene에서 공유하는 단일 ModelContainer
    let modelContainer: ModelContainer

    init() {
        do {
            let container = try ModelContainer(
                for: BlockProfile.self,
                BlockedSite.self,
                BlockedApp.self,
                FocusSession.self
            )
            modelContainer = container
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }

        let state = AppState()
        _appState = State(initialValue: state)
        _settingsViewModel = State(initialValue: SettingsViewModel())
        _themeManager = State(initialValue: ThemeManager.shared)

        #if DEBUG
        QAAutomationController.shared.startIfNeeded(
            appState: state,
            modelContext: modelContainer.mainContext
        )
        #endif
    }

    var body: some Scene {
        // MARK: - 메뉴바 (메인)
        // NOTE: .modelContainer()를 View 레벨에 직접 적용
        // MenuBarExtra의 Scene 레벨 수정자가 content view에 modelContext를 전파하지 않는 SwiftUI 버그 대응
        MenuBarExtra {
            MenuBarView()
                .modelContainer(modelContainer)
                .environment(appState)
                .environment(settingsViewModel)
                .environment(themeManager)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: appState.menuBarIcon)

                if appState.focusState == .focusing,
                   settingsViewModel.showMenuBarTime {
                    Text(appState.timer.remainingTime.formattedAsTimer)
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)

        // MARK: - 메인 대시보드 윈도우
        Window("Focus You 대시보드", id: "main-dashboard") {
            MainDashboardView()
                .modelContainer(modelContainer)
                .environment(appState)
                .environment(settingsViewModel)
                .environment(themeManager)
        }
        .defaultSize(width: 840, height: 620)

        // MARK: - 차단 목록 관리 윈도우
        Window("차단 목록 관리", id: "block-list") {
            BlockListView()
                .modelContainer(modelContainer)
                .environment(appState)
                .environment(themeManager)
        }
        .defaultSize(width: 520, height: 450)

        // MARK: - 프로필 윈도우
        Window("프로필", id: "profiles") {
            ProfileListView()
                .modelContainer(modelContainer)
                .environment(themeManager)
        }
        .defaultSize(width: 520, height: 400)

        // MARK: - 통계 윈도우
        Window("통계", id: "stats") {
            StatsView()
                .modelContainer(modelContainer)
                .environment(themeManager)
        }
        .defaultSize(width: 620, height: 700)

        // MARK: - 설정 윈도우
        Window("설정", id: "settings") {
            SettingsView()
                .environment(settingsViewModel)
                .environment(themeManager)
        }
        .defaultSize(width: 420, height: 360)
    }
}

// MARK: - AppDelegate (앱 시작/종료 관리)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "AppLifecycle"
    )
    private var isTerminationCleanupInProgress = false
    private var windowObservers: [Any] = []

    /// 앱 윈도우로 인식할 타이틀 (MenuBarExtra 팝오버 제외)
    private static let appWindowTitles: Set<String> = [
        "Focus You 대시보드", "차단 목록 관리", "프로필", "통계", "설정"
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // MenuBarExtra 초기화 최소 대기(0.3초) 후 버튼 폴링 시작
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.pollForStatusBarButton()
        }

        // 윈도우 열림/닫힘에 따라 Dock + Cmd+Tab 노출 전환
        setupWindowPolicyObservers()
    }

    // MARK: - Dynamic Activation Policy

    /// 앱 윈도우가 열리면 Dock/Cmd+Tab에 노출, 모두 닫히면 메뉴바 전용 복귀
    private func setupWindowPolicyObservers() {
        let nc = NotificationCenter.default
        windowObservers.append(
            nc.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil, queue: .main
            ) { [weak self] _ in self?.updateActivationPolicy() }
        )
        windowObservers.append(
            nc.addObserver(
                forName: NSWindow.willCloseNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.updateActivationPolicy()
                }
            }
        )
    }

    private func updateActivationPolicy() {
        let hasAppWindows = NSApp.windows.contains { window in
            window.isVisible && Self.appWindowTitles.contains(window.title)
        }
        let newPolicy: NSApplication.ActivationPolicy =
            hasAppWindows ? .regular : .accessory

        guard NSApp.activationPolicy() != newPolicy else { return }
        NSApp.setActivationPolicy(newPolicy)
        if newPolicy == .regular {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// 0.1초 간격으로 NSStatusBarButton을 폴링하여 발견 즉시 클릭
    private func pollForStatusBarButton(attempts: Int = 0) {
        let maxAttempts = 20 // 0.1초 × 20 = 최대 2초 추가 대기

        for window in NSApp.windows {
            if let button = Self.findStatusBarButton(in: window.contentView) {
                NSApp.activate(ignoringOtherApps: true)
                button.performClick(nil)
                return
            }
        }

        guard attempts < maxAttempts else {
            logger.warning("메뉴바 버튼을 찾지 못함 (타임아웃)")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.pollForStatusBarButton(attempts: attempts + 1)
        }
    }

    /// 뷰 계층을 재귀 탐색하여 NSStatusBarButton 찾기
    private static func findStatusBarButton(in view: NSView?) -> NSStatusBarButton? {
        guard let view else { return nil }
        if let button = view as? NSStatusBarButton { return button }
        for subview in view.subviews {
            if let button = findStatusBarButton(in: subview) { return button }
        }
        return nil
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminationCleanupInProgress else {
            return .terminateNow
        }

        // Window observer 정리
        for observer in windowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowObservers.removeAll()

        isTerminationCleanupInProgress = true

        Task { [weak self] in
            await self?.performTerminationCleanupAndReply()
        }

        return .terminateLater
    }

    private func performTerminationCleanupAndReply() async {
        let logger = self.logger
        let timeoutNanoseconds = UInt64(
            Constants.App.terminationCleanupTimeoutSeconds * 1_000_000_000
        )

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    try await BlockingCoordinator.shared.deactivateBlocking()
                } catch {
                    logger.error("앱 종료 시 차단 정리 실패: \(error.localizedDescription)")
                }
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            }

            _ = await group.next()
            group.cancelAll()
        }

        isTerminationCleanupInProgress = false
        NSApp.reply(toApplicationShouldTerminate: true)
    }
}
