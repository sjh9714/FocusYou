import SwiftUI
import os

// MARK: - 라이선스 관리자 (v2.0)
// Pro 구독 상태 관리 및 기능 게이팅
// App Store 출시 시 StoreKit 2 연결 예정

@MainActor
@Observable
final class LicenseManager {
    static let shared = LicenseManager()

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "LicenseManager"
    )
    private let defaults: UserDefaults

    /// Pro 활성화 여부
    private(set) var isPro: Bool {
        didSet {
            defaults.set(isPro, forKey: Constants.Subscription.isProKey)
            logger.info("Pro 상태 변경: \(self.isPro)")
        }
    }

    /// Pro 전용 기능 열거
    enum ProFeature: String, CaseIterable, Sendable {
        case overflow
        case ambientSound
        case schedule
        case keywordBlocking
        case allowlistMode
        case hardcoreMode
        case focusModeIntegration
        case shortcuts
        case calendarSync
        case appDimming
        case dataExport
        case unlimitedBlocks
        case unlimitedTimer
        case unlimitedProfiles
        case premiumThemes
        case advancedStats
        case advancedRetrospect
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Constants.Subscription.isProKey) != nil {
            isPro = defaults.bool(forKey: Constants.Subscription.isProKey)
        } else {
            isPro = false
        }
    }

    // MARK: - 한도 체크

    /// 웹사이트 추가 가능 여부
    func canAddWebsite(currentCount: Int) -> Bool {
        isPro || currentCount < Constants.Subscription.freeWebsiteLimit
    }

    /// 앱 추가 가능 여부
    func canAddApp(currentCount: Int) -> Bool {
        isPro || currentCount < Constants.Subscription.freeAppLimit
    }

    /// 프로필 추가 가능 여부
    func canAddProfile(currentCount: Int) -> Bool {
        isPro || currentCount < Constants.Subscription.freeProfileLimit
    }

    /// 테마 선택 가능 여부 (인덱스 기반)
    func canUseTheme(index: Int) -> Bool {
        isPro || index < Constants.Subscription.freeThemeLimit
    }

    /// 타이머 시간 사용 가능 여부
    func canUseTimerDuration(minutes: Int) -> Bool {
        isPro || minutes <= Constants.Subscription.freeTimerMaxMinutes
    }

    /// 통계 기간 사용 가능 여부
    func canUseStatsPeriod(_ period: String) -> Bool {
        isPro || Constants.Subscription.freeStatsPeriods.contains(period)
    }

    /// 회고 레벨 사용 가능 여부
    func canUseRetrospectLevel(_ level: Int) -> Bool {
        isPro || level <= Constants.Subscription.freeRetrospectMaxLevel
    }

    /// 특정 Pro 기능 사용 가능 여부
    func requiresPro(feature: ProFeature) -> Bool {
        !isPro
    }

    // MARK: - 구독 상태 갱신

    /// SubscriptionManager에서 호출: StoreKit 검증 결과 반영
    func updateProStatus(_ value: Bool) {
        isPro = value
    }

    // MARK: - 디버그 / 테스트

    #if DEBUG
    /// 디버그용: Pro 상태 토글
    func debugSetPro(_ value: Bool) {
        isPro = value
    }
    #endif
}
