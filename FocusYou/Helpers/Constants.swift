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
    }

    // MARK: - 차단

    enum Blocking {
        /// hosts 파일 경로
        static let hostsFilePath = "/etc/hosts"
        /// hosts 파일 백업 경로
        static let hostsBackupPath = "/tmp/focusyou_hosts_backup"
        /// 차단 시작 마커
        static let beginMarker = "# === Focus You BEGIN ==="
        /// 차단 종료 마커
        static let endMarker = "# === Focus You END ==="
        /// 리다이렉트 IP
        static let redirectIP = "127.0.0.1"
        /// 활성 상태 표시 파일
        static let activeIndicatorPath = "/tmp/focusyou.active"
    }

    // MARK: - 앱 정보

    enum App {
        static let bundleIdentifier = "com.yourname.focusyou"
        /// os.Logger subsystem
        static let subsystem = "com.yourname.focusyou"
        /// LaunchAgent 라벨
        static let launchAgentLabel = "com.yourname.focusyou.cleanup"
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
