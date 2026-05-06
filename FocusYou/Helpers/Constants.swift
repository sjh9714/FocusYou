import Foundation
import CoreGraphics

// MARK: - 앱 전체에서 사용되는 상수 정의

enum Constants {
    enum Distribution {
        #if APPSTORE
        static let isAppStoreBuild = true
        #else
        static let isAppStoreBuild = false
        #endif
    }

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

        // MARK: - 플로우모도로 (v1.0)

        /// 휴식 비율: 집중 시간의 1/5
        static let flowmodoroBreakRatio: Double = 0.2
        /// 최대 집중 시간 (초): 4시간
        static let flowmodoroMaxDuration: TimeInterval = 14400
    }

    // MARK: - 스트릭 (v1.0)

    enum Streak {
        /// 하루 최소 완료 세션 수
        static let minimumSessionsPerDay = 1
    }

    // MARK: - 차단

    enum Blocking {
        /// hosts 파일 경로
        #if APPSTORE
        static let hostsFilePath = ""
        #else
        static let hostsFilePath = "/etc/hosts"
        #endif
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
        #if APPSTORE
        static let helperPath = ""
        #else
        static let helperPath = "/usr/local/bin/focusyou-helper"
        #endif
        /// sudoers 엔트리 (헬퍼 NOPASSWD 허용)
        #if APPSTORE
        static let sudoersPath = ""
        #else
        static let sudoersPath = "/etc/sudoers.d/focusyou"
        #endif
    }

    // MARK: - 앱 정보

    enum App {
        static let bundleIdentifier = "com.sungjh.focusyou"
        /// os.Logger subsystem
        static let subsystem = "com.sungjh.focusyou"
        /// 앱 종료 시 차단 정리 대기 시간 (초)
        static let terminationCleanupTimeoutSeconds: TimeInterval = 3
        /// LaunchAgent 라벨
        #if APPSTORE
        static let launchAgentLabel = "com.sungjh.focusyou.appstore.disabled"
        #else
        static let launchAgentLabel = "com.sungjh.focusyou.cleanup"
        #endif
        /// LaunchAgent plist 경로
        static var launchAgentPath: String {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            #if APPSTORE
            return "\(home)/Library/Application Support/FocusYou/appstore-launch-agent-disabled.plist"
            #else
            return "\(home)/Library/LaunchAgents/\(launchAgentLabel).plist"
            #endif
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
        /// 윈도우 ID: 메인 대시보드
        static let mainDashboardWindowID = "main-dashboard"
        /// 윈도우 타이틀: 메인 대시보드
        static let mainDashboardWindowTitle = "Focus You 대시보드"
        /// 윈도우 타이틀: 설정
        static let settingsWindowTitle = "설정"
        /// 라이브 프리뷰 시 설정/대시보드 윈도우 간 간격
        static let livePreviewWindowGap: CGFloat = 16
        /// 대시보드 윈도우를 연 직후 배치 대기 시간
        static let livePreviewArrangeDelay: TimeInterval = 0.12
    }

    // MARK: - 설정

    enum Settings {
        static let showMenuBarTimeKey = "showMenuBarTime"
        static let playCompletionSoundKey = "playCompletionSound"
        static let showBlockedAppNotificationKey = "showBlockedAppNotification"

        static let selectedThemeIDKey = "selectedThemeID"
        static let debugFastTimerEnabledKey = "debugFastTimerEnabled"
        static let debugSecondsPerMinuteKey = "debugSecondsPerMinute"
        static let qaAutomationEnabledKey = "qaAutomationEnabled"
        static let qaAutomationCommandKey = "qaAutomationCommand"
        static let qaAutomationResultKey = "qaAutomationResult"
        static let qaAutomationHandledCommandIDKey = "qaAutomationHandledCommandID"

        static let showMenuBarTimeDefault = true
        static let playCompletionSoundDefault = true
        static let showBlockedAppNotificationDefault = true

        static let selectedThemeIDDefault = "crimson-focus"
        static let debugFastTimerEnabledDefault = false
        static let debugSecondsPerMinuteDefault = 5.0
        static let qaAutomationEnabledDefault = false
        static let debugSecondsPerMinuteRange: ClosedRange<Double> = 1...30

        // 외관 모드
        static let appearanceModeKey = "appearanceMode"
        static let appearanceModeDefault = "system"  // "system" | "light" | "dark"

        // 온보딩 (v1.0)
        static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
        static let hasCompletedOnboardingDefault = false

        // 의도 입력 & 회고 (v1.1)
        static let showIntentionInputKey = "showIntentionInput"
        static let showIntentionInputDefault = false
        static let showRetrospectKey = "showRetrospect"
        static let showRetrospectDefault = false

        // 회고 레벨 (v1.5)
        static let retrospectLevelKey = "retrospectLevel"
        static let retrospectLevelDefault = 1

        // 로그인 시 자동 시작 (v1.2)
        static let launchAtLoginKey = "launchAtLogin"
        static let launchAtLoginDefault = false

        // 캘린더 동기화 (v1.3)
        static let enableCalendarSyncKey = "enableCalendarSync"
        static let enableCalendarSyncDefault = false

        // 스케줄 (v1.3)
        static let enableScheduleKey = "enableSchedule"
        static let enableScheduleDefault = false

        // Focus Mode 연동 (v1.4)
        static let enableFocusModeKey = "enableFocusMode"
        static let enableFocusModeDefault = false

        // 번아웃 방지 (v1.5)
        static let enableBurnoutWarningsKey = "enableBurnoutWarnings"
        static let enableBurnoutWarningsDefault = false
        static let burnoutDailyLimitHoursKey = "burnoutDailyLimitHours"

        // 앱 언어 설정
        static let appLanguageKey = "appLanguage"
        static let appLanguageDefault = "system"  // "system" | "ko" | "en"

        // 동기부여 명언 (v1.x)
        static let showMotivationQuotesKey = "showMotivationQuotes"
        static let showMotivationQuotesDefault = false

        // 차단 전략 (v2.0)
        static let blockingStrategyKey = "blockingStrategy"
        static let blockingStrategyDefault = Distribution.isAppStoreBuild
            ? "networkExtension"
            : "hosts"  // "hosts" | "networkExtension"
    }

    // MARK: - 취소 강도 (v1.3)

    enum CancelIntensity {
        /// 잠금 시간 범위 (분)
        static let lockoutMinutesRange: ClosedRange<Int> = 1...30
        /// 기본 잠금 시간 (분)
        static let lockoutMinutesDefault = 5
        /// 비상 해제 대기 시간 (초)
        static let emergencyUnlockDuration: TimeInterval = 120
        /// 1일 최대 비상 해제 횟수
        static let maxEmergencyUnlocksPerDay = 1
    }

    // MARK: - 스케줄 (v1.3)

    enum Schedule {
        /// 스케줄 체크 간격 (초)
        static let checkIntervalSeconds: TimeInterval = 60
        /// 요일 심볼 (1=일, 2=월, ..., 7=토)
        static let weekdaySymbols: [String] = [
            String(localized: "weekday_sun"),
            String(localized: "weekday_mon"),
            String(localized: "weekday_tue"),
            String(localized: "weekday_wed"),
            String(localized: "weekday_thu"),
            String(localized: "weekday_fri"),
            String(localized: "weekday_sat"),
        ]
    }

    // MARK: - 테마 카테고리 (v1.3)

    enum ThemeCategory {
        /// 내부 ID (ThemeCatalog.json 키와 일치) — 비교/필터용
        static let all = ["미니멀", "따뜻한", "차가운", "자연", "네온", "파스텔"]
        static let icons: [String: String] = [
            "미니멀": "square.3.layers.3d.down.left",
            "따뜻한": "sun.max.fill",
            "차가운": "snowflake",
            "자연": "leaf.fill",
            "네온": "sparkles",
            "파스텔": "paintpalette.fill",
        ]
        static func displayName(_ id: String) -> String {
            switch id {
            case "미니멀": String(localized: "theme_category_minimal")
            case "따뜻한": String(localized: "theme_category_warm")
            case "차가운": String(localized: "theme_category_cool")
            case "자연": String(localized: "theme_category_nature")
            case "네온": String(localized: "theme_category_neon")
            case "파스텔": String(localized: "theme_category_pastel")
            default: id
            }
        }
    }

    // MARK: - 회고 (v1.5)

    enum Retrospect {
        /// 방해요소 태그 내부 ID (SwiftData에 저장됨)
        static let disruptionTagIDs = ["SNS", "이메일", "전화", "소음", "피곤"]
        /// 방해요소 태그 표시용 이름
        static let disruptionTags: [String] = disruptionTagIDs.map { disruptionTagDisplayName($0) }
        /// 레벨 이름
        static let levelNames: [String] = [
            String(localized: "retrospect_level_1"),
            String(localized: "retrospect_level_2"),
            String(localized: "retrospect_level_3"),
        ]
        static func disruptionTagDisplayName(_ id: String) -> String {
            switch id {
            case "SNS": String(localized: "disruption_sns")
            case "이메일": String(localized: "disruption_email")
            case "전화": String(localized: "disruption_phone")
            case "소음": String(localized: "disruption_noise")
            case "피곤": String(localized: "disruption_tired")
            default: id
            }
        }
    }

    // MARK: - 번아웃 방지 (v1.5)

    enum Burnout {
        /// 일일 집중 한계 기본값 (시간)
        static let dailyLimitHoursDefault = 6.0
        /// 일일 집중 한계 범위 (시간)
        static let dailyLimitHoursRange: ClosedRange<Double> = 2...12
        /// 스트레칭 알림 임계값 (초) — 90분
        static let stretchReminderThresholdSeconds: TimeInterval = 5400
        /// 배너 해제 타임스탬프 키
        static let bannerDismissedAtKey = "burnoutBannerDismissedAt"
        /// 번아웃 접근 경고 임계값 (초) — 30분
        static let approachingThresholdSeconds: TimeInterval = 1800
        /// 배너 해제 후 재표시 쿨다운 (초) — 24시간
        static let bannerCooldownSeconds: TimeInterval = 86400
    }

    // MARK: - 캘린더 (v1.4)

    enum CalendarSync {
        /// 캘린더 이벤트 색상 (빨간색 계열)
        static let calendarColor = CGColor(red: 0.9, green: 0.22, blue: 0.27, alpha: 1)
    }

    // MARK: - App Groups (v1.4)

    enum AppGroups {
        static let identifier = "group.com.sungjh.focusyou"
    }

    // MARK: - 위젯 (v1.4)

    enum Widget {
        static let focusStatusKind = "FocusStatusWidget"
        static let streakKind = "StreakWidget"
        static let refreshInterval: TimeInterval = 300
    }

    // MARK: - Network Extension (v2.0)

    enum NetworkExtension {
        /// System Extension 번들 ID
        static let extensionBundleID = "com.sungjh.focusyou.network-extension"
        /// System Extension 이름
        static let extensionName = "FocusYouFilter"
    }

    // MARK: - 디자인 토큰

    enum Design {
        // 간격 (4의 배수)
        static let spacingXS: CGFloat = 4
        static let spacingSM: CGFloat = 8
        static let spacingMD: CGFloat = 12
        static let spacingLG: CGFloat = 16
        static let spacingXL: CGFloat = 20
        static let spacingXXL: CGFloat = 24

        // 모서리
        static let cornerSM: CGFloat = 6
        static let cornerMD: CGFloat = 10
        static let cornerLG: CGFloat = 14
        static let cornerXL: CGFloat = 18

        // 카드
        static let cardPadding: CGFloat = 14

        // 아이콘
        static let iconSM: CGFloat = 14
        static let iconMD: CGFloat = 18
        static let iconLG: CGFloat = 24

        // 프로필 에디터
        static let profileIcons = [
            "shield.fill", "book.fill", "brain.head.profile", "laptopcomputer",
            "desktopcomputer", "pencil.and.outline", "lightbulb.fill", "target",
            "flame.fill", "leaf.fill", "moon.fill", "sun.max.fill",
            "graduationcap.fill", "music.note", "paintbrush.fill", "wrench.fill",
            "cup.and.saucer.fill", "figure.walk", "heart.fill", "star.fill",
        ]

        static let profileColors = [
            "#E63946", "#0077B6", "#2A9D8F", "#EF476F", "#FF9F1C", "#4361EE",
            "#8338EC", "#D81159", "#06D6A0", "#F4A261", "#6D597A", "#264653",
        ]
    }

    // MARK: - XP / 레벨 (v1.x)

    enum XP {
        /// 분당 기본 XP
        static let xpPerMinute: Double = 1.0
        /// 완료 보너스 배율 (+20%)
        static let completionBonusMultiplier: Double = 0.2
        /// 스트릭 일당 추가 배율 (+5%)
        static let streakBonusPerDay: Double = 0.05
        /// 스트릭 보너스 최대치 (10일 이상 = +50%)
        static let streakBonusCap: Double = 0.5
        /// 레벨 공식 계수: Level N threshold = N * (N-1) * multiplier
        static let thresholdMultiplier: Int = 25
    }

    // MARK: - 구독 (v2.0)

    enum Subscription {
        // 무료 한도
        static let freeWebsiteLimit = 10
        static let freeAppLimit = 5
        static let freeTimerMaxMinutes = 120
        static let freeProfileLimit = 1
        static let freeThemeLimit = 10
        static let freeRetrospectMaxLevel = 1

        // 무료 통계 기간 (Period rawValue 기반)
        static let freeStatsPeriods: Set<String> = ["today", "week"]

        // UserDefaults key
        static let isProKey = "subscription_isPro"

        // 가격 표시 문자열 (StoreKit 로드 실패 시 폴백)
        static let monthlyPrice = "$2.99"
        static let annualPrice = "$14.99"
        static let annualDiscountPrice = "$9.99"
        static let lifetimePrice = "$49.99"

        // StoreKit 2 Product ID
        static let monthlyProductID = "com.sungjh.focusyou.pro.monthly"
        static let annualProductID = "com.sungjh.focusyou.pro.annual"
        static let lifetimeProductID = "com.sungjh.focusyou.pro.lifetime"
        static let allProductIDs: Set<String> = [
            monthlyProductID, annualProductID, lifetimeProductID
        ]

        // Subscription Group
        static let subscriptionGroupID = "focusyou_pro"
    }

    // MARK: - 카테고리

    enum Category {
        /// 내부 ID (SwiftData・JSON 프리셋에 저장됨 — 변경 금지)
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

        /// UI 표시용 이름
        static func displayName(_ id: String) -> String {
            switch id {
            case sns: String(localized: "category_sns")
            case news: String(localized: "category_news")
            case video: String(localized: "category_video")
            case games: String(localized: "category_games")
            default: id
            }
        }
    }
}
