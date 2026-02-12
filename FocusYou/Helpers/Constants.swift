import Foundation

// MARK: - 앱 전체에서 사용되는 상수 정의

enum Constants {

    // MARK: - 타이머

    enum Timer {
        /// 타이머 프리셋 (분)
        static let presets: [Int] = [25, 45, 60, 120]
        /// 최소 타이머 시간 (분)
        static let minimumMinutes = 1
        /// 최대 타이머 시간 (분)
        static let maximumMinutes = 240
        /// 팝오버 열림 시 타이머 갱신 주기 (초)
        static let activeRefreshInterval: TimeInterval = 1.0
        /// 팝오버 닫힘 시 타이머 갱신 주기 (초)
        static let backgroundRefreshInterval: TimeInterval = 60.0

        // MARK: - 뽀모도로

        static let pomodoroFocusDefaultMinutes = 25
        static let pomodoroShortBreakDefaultMinutes = 5
        static let pomodoroLongBreakDefaultMinutes = 15
        static let pomodoroCyclesDefault = 4

        static let pomodoroFocusRange = 10...90
        static let pomodoroShortBreakRange = 3...30
        static let pomodoroLongBreakRange = 10...45
        static let pomodoroCyclesRange = 2...8
    }

    // MARK: - 차단

    enum Blocking {
        /// hosts 파일 경로
        static let hostsFilePath = "/etc/hosts"
        /// 앱 내부 상태 파일 디렉터리
        private static var appStateDirectory: String {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return "\(home)/Library/Application Support/FocusYou"
        }
        /// hosts 파일 백업 경로 (재부팅 이후에도 유지)
        static var hostsBackupPath: String {
            "\(appStateDirectory)/hosts.backup"
        }
        /// 차단 시작 마커
        static let beginMarker = "# === Focus You BEGIN ==="
        /// 차단 종료 마커
        static let endMarker = "# === Focus You END ==="
        /// 리다이렉트 IP (IPv4)
        static let redirectIP = "0.0.0.0"
        /// 리다이렉트 IP (IPv6 loopback)
        static let redirectIPv6 = "::1"
        /// 리다이렉트 IP (IPv6 link-local)
        static let redirectIPv6LinkLocal = "fe80::1%lo0"
        /// 활성 상태 표시 파일 (재부팅 이후에도 유지)
        static var activeIndicatorPath: String {
            "\(appStateDirectory)/blocking.active"
        }
        /// 영구 헬퍼 스크립트 (비밀번호 없는 hosts 변경용)
        static let helperPath = "/usr/local/bin/focusyou-helper"
        /// sudoers 엔트리 (헬퍼 NOPASSWD 허용)
        static let sudoersPath = "/etc/sudoers.d/focusyou"
    }

    // MARK: - 앱 정보

    enum App {
        static let bundleIdentifier = "com.sungjh.focusyou"
        /// os.Logger subsystem
        static let subsystem = "com.sungjh.focusyou"
        /// 앱 종료 시 차단 정리 대기 시간 (초)
        static let terminationCleanupTimeoutSeconds: TimeInterval = 3
        /// LaunchAgent 라벨
        static let launchAgentLabel = "com.sungjh.focusyou.cleanup"
        /// LaunchAgent plist 경로
        static var launchAgentPath: String {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return "\(home)/Library/LaunchAgents/\(launchAgentLabel).plist"
        }
    }

    // MARK: - UI

    enum UI {
        /// 팝오버 너비
        static let popoverWidth: CGFloat = 340
        /// 팝오버 최소 높이
        static let popoverMinHeight: CGFloat = 300
        /// 메뉴바 아이콘 (유휴)
        static let menuBarIconIdle = "shield.fill"
        /// 메뉴바 아이콘 (활성)
        static let menuBarIconActive = "shield.checkered"
    }

    // MARK: - 설정

    enum Settings {
        static let showMenuBarTimeKey = "showMenuBarTime"
        static let playCompletionSoundKey = "playCompletionSound"
        static let showBlockedAppNotificationKey = "showBlockedAppNotification"
        static let debugFastTimerEnabledKey = "debugFastTimerEnabled"
        static let debugSecondsPerMinuteKey = "debugSecondsPerMinute"

        static let showMenuBarTimeDefault = true
        static let playCompletionSoundDefault = true
        static let showBlockedAppNotificationDefault = true
        static let debugFastTimerEnabledDefault = false
        static let debugSecondsPerMinuteDefault = 5.0
        static let debugSecondsPerMinuteRange: ClosedRange<Double> = 1...30
    }

    // MARK: - 카테고리

    enum Category {
        static let sns = "SNS"
        static let news = "뉴스"
        static let video = "동영상"
        static let games = "게임"

        static let all = [sns, news, video, games]

        static let icons: [String: String] = [
            sns: "bubble.left.and.bubble.right.fill",
            news: "newspaper.fill",
            video: "play.rectangle.fill",
            games: "gamecontroller.fill"
        ]
    }
}
