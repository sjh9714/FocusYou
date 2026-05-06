import SwiftUI
import os

// MARK: - 설정 ViewModel
// v0.1 기본 설정값 관리

@MainActor
@Observable
final class SettingsViewModel {
    private let defaults: UserDefaults
    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "SettingsViewModel"
    )

    /// 메뉴바에 남은 시간 표시
    var showMenuBarTime: Bool {
        didSet {
            defaults.set(showMenuBarTime, forKey: Constants.Settings.showMenuBarTimeKey)
        }
    }

    /// 완료 시 사운드 재생
    var playCompletionSound: Bool {
        didSet {
            defaults.set(playCompletionSound, forKey: Constants.Settings.playCompletionSoundKey)
        }
    }

    /// 차단된 앱 알림 표시
    var showBlockedAppNotification: Bool {
        didSet {
            defaults.set(
                showBlockedAppNotification,
                forKey: Constants.Settings.showBlockedAppNotificationKey
            )
        }
    }

    /// 외관 모드: "system" | "light" | "dark"
    var appearanceMode: String {
        didSet {
            defaults.set(
                appearanceMode,
                forKey: Constants.Settings.appearanceModeKey
            )
        }
    }

    /// 현재 외관 모드에 대응하는 ColorScheme (system일 경우 nil)
    var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    /// 온보딩 완료 여부 (v1.0)
    var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(
                hasCompletedOnboarding,
                forKey: Constants.Settings.hasCompletedOnboardingKey
            )
        }
    }

    /// 세션 시작 전 의도 입력 표시 (v1.1)
    var showIntentionInput: Bool {
        didSet {
            defaults.set(
                showIntentionInput,
                forKey: Constants.Settings.showIntentionInputKey
            )
        }
    }

    /// 세션 완료 후 회고 표시 (v1.1)
    var showRetrospect: Bool {
        didSet {
            defaults.set(
                showRetrospect,
                forKey: Constants.Settings.showRetrospectKey
            )
        }
    }

    /// 회고 레벨 (v1.5): 1=간단, 2=보통, 3=상세
    var retrospectLevel: Int {
        didSet {
            let clamped = min(max(retrospectLevel, 1), 3)
            if clamped != retrospectLevel {
                retrospectLevel = clamped
                return
            }
            defaults.set(
                retrospectLevel,
                forKey: Constants.Settings.retrospectLevelKey
            )
        }
    }

    /// 로그인 시 자동 시작 (v1.2)
    var launchAtLogin: Bool {
        didSet {
            defaults.set(
                launchAtLogin,
                forKey: Constants.Settings.launchAtLoginKey
            )
            LaunchAtLoginManager.setEnabled(launchAtLogin)
        }
    }

    /// 캘린더 동기화 (v1.3)
    var enableCalendarSync: Bool {
        didSet {
            defaults.set(
                enableCalendarSync,
                forKey: Constants.Settings.enableCalendarSyncKey
            )
            if enableCalendarSync {
                Task { await CalendarSyncService.shared.requestAccess() }
            }
        }
    }

    /// 자동 스케줄 (v1.3)
    var enableSchedule: Bool {
        didSet {
            defaults.set(
                enableSchedule,
                forKey: Constants.Settings.enableScheduleKey
            )
            if enableSchedule {
                ScheduleManager.shared.startMonitoring()
            } else {
                ScheduleManager.shared.stopMonitoring()
            }
        }
    }

    /// macOS Focus Mode 연동 (v1.4)
    var enableFocusMode: Bool {
        didSet {
            defaults.set(
                enableFocusMode,
                forKey: Constants.Settings.enableFocusModeKey
            )
        }
    }

    /// 앱 내 언어 설정
    var appLanguage: String {
        didSet {
            defaults.set(appLanguage, forKey: Constants.Settings.appLanguageKey)
            if appLanguage == "system" {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set([appLanguage], forKey: "AppleLanguages")
            }
        }
    }

    /// 동기부여 명언 표시 (v1.x)
    var showMotivationQuotes: Bool {
        didSet {
            defaults.set(
                showMotivationQuotes,
                forKey: Constants.Settings.showMotivationQuotesKey
            )
        }
    }

    /// 차단 전략 (v2.0): "hosts" | "networkExtension"
    var blockingStrategy: String {
        didSet {
            if Constants.Distribution.isAppStoreBuild,
               blockingStrategy != BlockingStrategy.networkExtension.rawValue {
                blockingStrategy = BlockingStrategy.networkExtension.rawValue
                defaults.set(
                    BlockingStrategy.networkExtension.rawValue,
                    forKey: Constants.Settings.blockingStrategyKey
                )
                return
            }

            defaults.set(
                blockingStrategy,
                forKey: Constants.Settings.blockingStrategyKey
            )
            // 코디네이터에 새 차단기 교체
            Task {
                let strategy = BlockingStrategy(rawValue: blockingStrategy) ?? .hosts
                let newBlocker = WebsiteBlockerFactory.create(strategy: strategy)
                do {
                    try await BlockingCoordinator.shared.swapBlocker(to: newBlocker)
                } catch {
                    // 차단 활성 중 — 다음 세션 종료 시 자동 적용
                    logger.info("차단 전략 변경은 현재 세션 종료 후 적용됩니다")
                }
            }
        }
    }

    /// 번아웃 방지 경고 (v1.5)
    var enableBurnoutWarnings: Bool {
        didSet {
            defaults.set(
                enableBurnoutWarnings,
                forKey: Constants.Settings.enableBurnoutWarningsKey
            )
        }
    }

    /// 일일 집중 한계 (시간, v1.5)
    var burnoutDailyLimitHours: Double {
        didSet {
            let clamped = min(
                max(burnoutDailyLimitHours, Constants.Burnout.dailyLimitHoursRange.lowerBound),
                Constants.Burnout.dailyLimitHoursRange.upperBound
            )
            if clamped != burnoutDailyLimitHours {
                burnoutDailyLimitHours = clamped
                return
            }
            defaults.set(
                burnoutDailyLimitHours,
                forKey: Constants.Settings.burnoutDailyLimitHoursKey
            )
        }
    }

    #if DEBUG
    /// 디버그: Fast Timer 토글
    var debugFastTimerEnabled: Bool {
        didSet {
            defaults.set(
                debugFastTimerEnabled,
                forKey: Constants.Settings.debugFastTimerEnabledKey
            )
        }
    }

    /// 디버그: 1분을 몇 초로 압축할지
    var debugSecondsPerMinute: Double {
        didSet {
            let normalized = min(
                max(
                    debugSecondsPerMinute,
                    Constants.Settings.debugSecondsPerMinuteRange.lowerBound
                ),
                Constants.Settings.debugSecondsPerMinuteRange.upperBound
            )
            if normalized != debugSecondsPerMinute {
                debugSecondsPerMinute = normalized
                return
            }
            defaults.set(
                debugSecondsPerMinute,
                forKey: Constants.Settings.debugSecondsPerMinuteKey
            )
        }
    }
    #endif

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        showMenuBarTime = Self.boolValue(
            forKey: Constants.Settings.showMenuBarTimeKey,
            defaults: defaults,
            defaultValue: Constants.Settings.showMenuBarTimeDefault
        )
        playCompletionSound = Self.boolValue(
            forKey: Constants.Settings.playCompletionSoundKey,
            defaults: defaults,
            defaultValue: Constants.Settings.playCompletionSoundDefault
        )
        showBlockedAppNotification = Self.boolValue(
            forKey: Constants.Settings.showBlockedAppNotificationKey,
            defaults: defaults,
            defaultValue: Constants.Settings.showBlockedAppNotificationDefault
        )
        appearanceMode = Self.stringValue(
            forKey: Constants.Settings.appearanceModeKey,
            defaults: defaults,
            defaultValue: Constants.Settings.appearanceModeDefault
        )
        hasCompletedOnboarding = Self.boolValue(
            forKey: Constants.Settings.hasCompletedOnboardingKey,
            defaults: defaults,
            defaultValue: Constants.Settings.hasCompletedOnboardingDefault
        )
        showIntentionInput = Self.boolValue(
            forKey: Constants.Settings.showIntentionInputKey,
            defaults: defaults,
            defaultValue: Constants.Settings.showIntentionInputDefault
        )
        showRetrospect = Self.boolValue(
            forKey: Constants.Settings.showRetrospectKey,
            defaults: defaults,
            defaultValue: Constants.Settings.showRetrospectDefault
        )
        retrospectLevel = Self.intValue(
            forKey: Constants.Settings.retrospectLevelKey,
            defaults: defaults,
            defaultValue: Constants.Settings.retrospectLevelDefault
        )
        launchAtLogin = Self.boolValue(
            forKey: Constants.Settings.launchAtLoginKey,
            defaults: defaults,
            defaultValue: Constants.Settings.launchAtLoginDefault
        )
        enableCalendarSync = Self.boolValue(
            forKey: Constants.Settings.enableCalendarSyncKey,
            defaults: defaults,
            defaultValue: Constants.Settings.enableCalendarSyncDefault
        )
        enableSchedule = Self.boolValue(
            forKey: Constants.Settings.enableScheduleKey,
            defaults: defaults,
            defaultValue: Constants.Settings.enableScheduleDefault
        )
        enableFocusMode = Self.boolValue(
            forKey: Constants.Settings.enableFocusModeKey,
            defaults: defaults,
            defaultValue: Constants.Settings.enableFocusModeDefault
        )
        appLanguage = Self.stringValue(
            forKey: Constants.Settings.appLanguageKey,
            defaults: defaults,
            defaultValue: Constants.Settings.appLanguageDefault
        )
        showMotivationQuotes = Self.boolValue(
            forKey: Constants.Settings.showMotivationQuotesKey,
            defaults: defaults,
            defaultValue: Constants.Settings.showMotivationQuotesDefault
        )
        let initialBlockingStrategy = Constants.Distribution.isAppStoreBuild
            ? BlockingStrategy.networkExtension.rawValue
            : Self.stringValue(
                forKey: Constants.Settings.blockingStrategyKey,
                defaults: defaults,
                defaultValue: Constants.Settings.blockingStrategyDefault
            )
        blockingStrategy = initialBlockingStrategy
        if Constants.Distribution.isAppStoreBuild {
            defaults.set(
                initialBlockingStrategy,
                forKey: Constants.Settings.blockingStrategyKey
            )
        }
        enableBurnoutWarnings = Self.boolValue(
            forKey: Constants.Settings.enableBurnoutWarningsKey,
            defaults: defaults,
            defaultValue: Constants.Settings.enableBurnoutWarningsDefault
        )
        burnoutDailyLimitHours = Self.doubleValue(
            forKey: Constants.Settings.burnoutDailyLimitHoursKey,
            defaults: defaults,
            defaultValue: Constants.Burnout.dailyLimitHoursDefault
        )
        #if DEBUG
        debugFastTimerEnabled = Self.boolValue(
            forKey: Constants.Settings.debugFastTimerEnabledKey,
            defaults: defaults,
            defaultValue: Constants.Settings.debugFastTimerEnabledDefault
        )

        let rawSeconds = Self.doubleValue(
            forKey: Constants.Settings.debugSecondsPerMinuteKey,
            defaults: defaults,
            defaultValue: Constants.Settings.debugSecondsPerMinuteDefault
        )
        debugSecondsPerMinute = min(
            max(rawSeconds, Constants.Settings.debugSecondsPerMinuteRange.lowerBound),
            Constants.Settings.debugSecondsPerMinuteRange.upperBound
        )
        #endif
    }

    private static func boolValue(
        forKey key: String,
        defaults: UserDefaults,
        defaultValue: Bool
    ) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }

    private static func intValue(
        forKey key: String,
        defaults: UserDefaults,
        defaultValue: Int
    ) -> Int {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.integer(forKey: key)
    }

    private static func doubleValue(
        forKey key: String,
        defaults: UserDefaults,
        defaultValue: Double
    ) -> Double {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.double(forKey: key)
    }

    private static func stringValue(
        forKey key: String,
        defaults: UserDefaults,
        defaultValue: String
    ) -> String {
        defaults.string(forKey: key) ?? defaultValue
    }
}
