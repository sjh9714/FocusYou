import XCTest
@testable import Focus_You

final class LicenseManagerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "FocusYouTests.License.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - 기본 상태

    @MainActor
    func testDefaultIsNotPro() {
        let manager = LicenseManager(defaults: defaults)
        XCTAssertFalse(manager.isPro)
    }

    @MainActor
    func testDebugSetProPersists() {
        let manager = LicenseManager(defaults: defaults)
        manager.debugSetPro(true)

        XCTAssertTrue(manager.isPro)
        XCTAssertTrue(defaults.bool(forKey: Constants.Subscription.isProKey))
    }

    @MainActor
    func testProStateRestoresFromDefaults() {
        defaults.set(true, forKey: Constants.Subscription.isProKey)
        let manager = LicenseManager(defaults: defaults)

        XCTAssertTrue(manager.isPro)
    }

    // MARK: - 웹사이트 한도

    @MainActor
    func testCanAddWebsite_BelowLimit() {
        let manager = LicenseManager(defaults: defaults)
        let limit = Constants.Subscription.freeWebsiteLimit

        XCTAssertTrue(manager.canAddWebsite(currentCount: 0))
        XCTAssertTrue(manager.canAddWebsite(currentCount: limit - 1))
    }

    @MainActor
    func testCanAddWebsite_AtLimit() {
        let manager = LicenseManager(defaults: defaults)
        let limit = Constants.Subscription.freeWebsiteLimit

        XCTAssertFalse(manager.canAddWebsite(currentCount: limit))
    }

    @MainActor
    func testCanAddWebsite_AboveLimit() {
        let manager = LicenseManager(defaults: defaults)
        let limit = Constants.Subscription.freeWebsiteLimit

        XCTAssertFalse(manager.canAddWebsite(currentCount: limit + 1))
    }

    @MainActor
    func testCanAddWebsite_ProIgnoresLimit() {
        let manager = LicenseManager(defaults: defaults)
        manager.debugSetPro(true)

        XCTAssertTrue(manager.canAddWebsite(currentCount: 100))
    }

    // MARK: - 앱 한도

    @MainActor
    func testCanAddApp_BelowLimit() {
        let manager = LicenseManager(defaults: defaults)
        let limit = Constants.Subscription.freeAppLimit

        XCTAssertTrue(manager.canAddApp(currentCount: 0))
        XCTAssertTrue(manager.canAddApp(currentCount: limit - 1))
    }

    @MainActor
    func testCanAddApp_AtLimit() {
        let manager = LicenseManager(defaults: defaults)
        let limit = Constants.Subscription.freeAppLimit

        XCTAssertFalse(manager.canAddApp(currentCount: limit))
    }

    @MainActor
    func testCanAddApp_ProIgnoresLimit() {
        let manager = LicenseManager(defaults: defaults)
        manager.debugSetPro(true)

        XCTAssertTrue(manager.canAddApp(currentCount: 100))
    }

    // MARK: - 프로필 한도

    @MainActor
    func testCanAddProfile_BelowLimit() {
        let manager = LicenseManager(defaults: defaults)

        XCTAssertTrue(manager.canAddProfile(currentCount: 0))
    }

    @MainActor
    func testCanAddProfile_AtLimit() {
        let manager = LicenseManager(defaults: defaults)
        let limit = Constants.Subscription.freeProfileLimit

        XCTAssertFalse(manager.canAddProfile(currentCount: limit))
    }

    @MainActor
    func testCanAddProfile_ProIgnoresLimit() {
        let manager = LicenseManager(defaults: defaults)
        manager.debugSetPro(true)

        XCTAssertTrue(manager.canAddProfile(currentCount: 100))
    }

    // MARK: - 테마 한도

    @MainActor
    func testCanUseTheme_BelowLimit() {
        let manager = LicenseManager(defaults: defaults)

        XCTAssertTrue(manager.canUseTheme(index: 0))
        XCTAssertTrue(manager.canUseTheme(index: Constants.Subscription.freeThemeLimit - 1))
    }

    @MainActor
    func testCanUseTheme_AtLimit() {
        let manager = LicenseManager(defaults: defaults)

        XCTAssertFalse(manager.canUseTheme(index: Constants.Subscription.freeThemeLimit))
    }

    @MainActor
    func testCanUseTheme_ProIgnoresLimit() {
        let manager = LicenseManager(defaults: defaults)
        manager.debugSetPro(true)

        XCTAssertTrue(manager.canUseTheme(index: 100))
    }

    // MARK: - 타이머 한도

    @MainActor
    func testCanUseTimerDuration_AtLimit() {
        let manager = LicenseManager(defaults: defaults)

        XCTAssertTrue(manager.canUseTimerDuration(minutes: Constants.Subscription.freeTimerMaxMinutes))
    }

    @MainActor
    func testCanUseTimerDuration_AboveLimit() {
        let manager = LicenseManager(defaults: defaults)

        XCTAssertFalse(manager.canUseTimerDuration(minutes: Constants.Subscription.freeTimerMaxMinutes + 1))
    }

    @MainActor
    func testCanUseTimerDuration_ProIgnoresLimit() {
        let manager = LicenseManager(defaults: defaults)
        manager.debugSetPro(true)

        XCTAssertTrue(manager.canUseTimerDuration(minutes: 500))
    }

    // MARK: - 통계 기간 한도

    @MainActor
    func testCanUseStatsPeriod_FreePeriods() {
        let manager = LicenseManager(defaults: defaults)

        for period in Constants.Subscription.freeStatsPeriods {
            XCTAssertTrue(manager.canUseStatsPeriod(period), "\(period)는 무료여야 합니다")
        }
    }

    @MainActor
    func testCanUseStatsPeriod_ProPeriods() {
        let manager = LicenseManager(defaults: defaults)

        XCTAssertFalse(manager.canUseStatsPeriod("month"))
        XCTAssertFalse(manager.canUseStatsPeriod("year"))
    }

    @MainActor
    func testCanUseStatsPeriod_ProIgnoresLimit() {
        let manager = LicenseManager(defaults: defaults)
        manager.debugSetPro(true)

        XCTAssertTrue(manager.canUseStatsPeriod("month"))
        XCTAssertTrue(manager.canUseStatsPeriod("year"))
    }

    // MARK: - 회고 레벨 한도

    @MainActor
    func testCanUseRetrospectLevel_FreeLevel() {
        let manager = LicenseManager(defaults: defaults)

        XCTAssertTrue(manager.canUseRetrospectLevel(1))
    }

    @MainActor
    func testCanUseRetrospectLevel_ProLevels() {
        let manager = LicenseManager(defaults: defaults)

        XCTAssertFalse(manager.canUseRetrospectLevel(2))
        XCTAssertFalse(manager.canUseRetrospectLevel(3))
    }

    @MainActor
    func testCanUseRetrospectLevel_ProIgnoresLimit() {
        let manager = LicenseManager(defaults: defaults)
        manager.debugSetPro(true)

        XCTAssertTrue(manager.canUseRetrospectLevel(3))
    }

    // MARK: - Pro 기능 체크

    @MainActor
    func testRequiresPro_FreeUser() {
        let manager = LicenseManager(defaults: defaults)

        for feature in LicenseManager.ProFeature.allCases {
            XCTAssertTrue(manager.requiresPro(feature: feature),
                          "\(feature.rawValue)는 무료 사용자에게 Pro 필요해야 합니다")
        }
    }

    @MainActor
    func testRequiresPro_ProUser() {
        let manager = LicenseManager(defaults: defaults)
        manager.debugSetPro(true)

        for feature in LicenseManager.ProFeature.allCases {
            XCTAssertFalse(manager.requiresPro(feature: feature),
                           "\(feature.rawValue)는 Pro 사용자에게 접근 가능해야 합니다")
        }
    }
}
