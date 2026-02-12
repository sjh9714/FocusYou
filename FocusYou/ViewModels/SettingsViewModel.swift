import SwiftUI

// MARK: - 설정 ViewModel
// v0.1 기본 설정값 관리

@MainActor
@Observable
final class SettingsViewModel {
    /// 메뉴바에 남은 시간 표시
    @ObservationIgnored
    @AppStorage("showMenuBarTime") var showMenuBarTime = true

    /// 완료 시 사운드 재생
    @ObservationIgnored
    @AppStorage("playCompletionSound") var playCompletionSound = true

    /// 차단된 앱 알림 표시
    @ObservationIgnored
    @AppStorage("showBlockedAppNotification") var showBlockedAppNotification = true
}
