import SwiftUI

// MARK: - 설정 ViewModel
// v0.1 기본 설정값 관리

@MainActor
@Observable
final class SettingsViewModel {
    private let defaults: UserDefaults

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
}
