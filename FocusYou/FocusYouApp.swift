import SwiftUI
import SwiftData

@main
struct FocusYouApp: App {
    @State private var appState = AppState()
    @State private var settingsViewModel = SettingsViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// 모든 Scene에서 공유하는 단일 ModelContainer
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: BlockProfile.self,
                BlockedSite.self,
                BlockedApp.self,
                FocusSession.self
            )
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
    }

    var body: some Scene {
        // MARK: - 메뉴바 (메인)
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .environment(settingsViewModel)
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
        .modelContainer(modelContainer)

        // MARK: - 차단 목록 관리 윈도우
        Window("차단 목록 관리", id: "block-list") {
            BlockListView()
                .environment(appState)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 520, height: 450)

        // MARK: - 설정 윈도우
        Window("설정", id: "settings") {
            SettingsView()
                .environment(settingsViewModel)
        }
        .defaultSize(width: 400, height: 250)
    }
}

// MARK: - AppDelegate (앱 종료 시 안전장치)

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // 앱 종료 시 차단이 활성화되어 있으면 정리
        Task {
            try? await BlockingCoordinator.shared.deactivateBlocking()
        }
    }
}
