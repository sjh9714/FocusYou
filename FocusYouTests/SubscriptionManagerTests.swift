import Foundation
import Testing
@testable import Focus_You

// MARK: - 구독 관련 테스트

@Suite("Subscription")
@MainActor
struct SubscriptionManagerTests {

    // MARK: - Product ID 상수

    @Test("Product ID 형식 확인")
    func testProductIDs() {
        #expect(Constants.Subscription.monthlyProductID == "com.sungjh.focusyou.pro.monthly")
        #expect(Constants.Subscription.annualProductID == "com.sungjh.focusyou.pro.annual")
        #expect(Constants.Subscription.lifetimeProductID == "com.sungjh.focusyou.pro.lifetime")
    }

    @Test("allProductIDs에 3개 상품 포함")
    func testAllProductIDs() {
        let ids = Constants.Subscription.allProductIDs
        #expect(ids.count == 3)
        #expect(ids.contains(Constants.Subscription.monthlyProductID))
        #expect(ids.contains(Constants.Subscription.annualProductID))
        #expect(ids.contains(Constants.Subscription.lifetimeProductID))
    }

    @Test("Subscription Group ID 확인")
    func testSubscriptionGroupID() {
        #expect(Constants.Subscription.subscriptionGroupID == "focusyou_pro")
    }

    @Test("concurrent product load coordinator calls share one request")
    func concurrentProductLoadCoordinatorCallsShareOneRequest() async throws {
        let counter = LockedCounter()
        let coordinator = SubscriptionProductLoadCoordinator<String>()

        async let first = coordinator.load {
            counter.increment()
            try await Task.sleep(nanoseconds: 50_000_000)
            return ["loaded"]
        }

        async let second = coordinator.load {
            counter.increment()
            try await Task.sleep(nanoseconds: 50_000_000)
            return ["loaded"]
        }

        let values = try await first + second

        #expect(values == ["loaded", "loaded"])
        #expect(counter.value == 1)
    }

    @Test("concurrent product loads await the same in-flight request")
    func testProductLoadCoordinatorCoalescesConcurrentLoads() async throws {
        let coordinator = SubscriptionProductLoadCoordinator<Int>()
        let counter = ProductLoadCallCounter()

        let loader: @Sendable () async throws -> [Int] = {
            await counter.increment()
            try await Task.sleep(nanoseconds: 100_000_000)
            return [1, 2, 3]
        }

        async let firstLoad = coordinator.load(using: loader)
        async let secondLoad = coordinator.load(using: loader)

        let (firstProducts, secondProducts) = try await (firstLoad, secondLoad)

        #expect(firstProducts == [1, 2, 3])
        #expect(secondProducts == [1, 2, 3])
        #expect(await counter.count == 1)
    }

    @Test("paywall presents no purchasable plans when StoreKit returns no products")
    func testPaywallPlansEmptyWhenProductsUnavailable() {
        let visibleIDs = PaywallPlanPresentation.visibleProductIDs(from: [])

        #expect(visibleIDs.isEmpty)
    }

    @Test("paywall hides lifetime unless StoreKit returns the lifetime product")
    func testPaywallHidesLifetimeWhenProductMissing() {
        let visibleIDs = PaywallPlanPresentation.visibleProductIDs(
            from: [
                Constants.Subscription.monthlyProductID,
                Constants.Subscription.annualProductID,
            ]
        )

        #expect(visibleIDs == [
            Constants.Subscription.annualProductID,
            Constants.Subscription.monthlyProductID,
        ])
        #expect(!visibleIDs.contains(Constants.Subscription.lifetimeProductID))
    }

    @Test("lifetime disclosure uses non-renewing wording")
    func testLifetimeDisclosureIsNotRenewing() {
        #expect(
            PaywallPlanPresentation.renewalDisclosureKey(
                for: Constants.Subscription.lifetimeProductID
            ) == "subscription_lifetime_disclosure"
        )
    }

    // MARK: - LicenseManager.updateProStatus

    @Test("updateProStatus(true) → isPro == true")
    func testUpdateProStatus_true() {
        let suiteName = "test.subscription.pro.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removeObject(forKey: Constants.Subscription.isProKey)

        let manager = LicenseManager(defaults: defaults)
        #expect(manager.isPro == false)

        manager.updateProStatus(true)
        #expect(manager.isPro == true)

        defaults.removeSuite(named: suiteName)
    }

    @Test("updateProStatus(false) → isPro == false")
    func testUpdateProStatus_false() {
        let suiteName = "test.subscription.free.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removeObject(forKey: Constants.Subscription.isProKey)

        let manager = LicenseManager(defaults: defaults)
        manager.updateProStatus(true)
        #expect(manager.isPro == true)

        manager.updateProStatus(false)
        #expect(manager.isPro == false)

        defaults.removeSuite(named: suiteName)
    }

    @Test("updateProStatus는 UserDefaults에 저장")
    func testUpdateProStatus_persists() {
        let suiteName = "test.subscription.persist"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removeObject(forKey: Constants.Subscription.isProKey)

        let manager = LicenseManager(defaults: defaults)
        manager.updateProStatus(true)

        #expect(defaults.bool(forKey: Constants.Subscription.isProKey) == true)

        // 정리
        defaults.removeSuite(named: suiteName)
    }

    // MARK: - 무료 한도 상수

    @Test("무료 한도 기본값 확인")
    func testFreeLimits() {
        #expect(Constants.Subscription.freeWebsiteLimit == 10)
        #expect(Constants.Subscription.freeAppLimit == 5)
        #expect(Constants.Subscription.freeTimerMaxMinutes == 120)
        #expect(Constants.Subscription.freeProfileLimit == 1)
        #expect(Constants.Subscription.freeThemeLimit == 10)
        #expect(Constants.Subscription.freeRetrospectMaxLevel == 1)
    }

    // MARK: - LicenseManager 게이팅

    @Test("무료 사용자: 한도 내 허용")
    func testGating_freeWithinLimits() {
        let suiteName = "test.gating.free.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removeObject(forKey: Constants.Subscription.isProKey)

        let manager = LicenseManager(defaults: defaults)
        #expect(manager.canAddWebsite(currentCount: 5) == true)
        #expect(manager.canAddApp(currentCount: 3) == true)
        #expect(manager.canAddProfile(currentCount: 0) == true)
        #expect(manager.canUseTimerDuration(minutes: 60) == true)

        defaults.removeSuite(named: suiteName)
    }

    @Test("무료 사용자: 한도 초과 차단")
    func testGating_freeExceedLimits() {
        let suiteName = "test.gating.free2.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removeObject(forKey: Constants.Subscription.isProKey)

        let manager = LicenseManager(defaults: defaults)
        #expect(manager.canAddWebsite(currentCount: 10) == false)
        #expect(manager.canAddApp(currentCount: 5) == false)
        #expect(manager.canAddProfile(currentCount: 1) == false)
        #expect(manager.canUseTimerDuration(minutes: 180) == false)

        defaults.removeSuite(named: suiteName)
    }

    @Test("Pro 사용자: 모든 한도 무시")
    func testGating_proUnlimited() {
        let suiteName = "test.gating.pro.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removeObject(forKey: Constants.Subscription.isProKey)

        let manager = LicenseManager(defaults: defaults)
        manager.updateProStatus(true)
        #expect(manager.canAddWebsite(currentCount: 100) == true)
        #expect(manager.canAddApp(currentCount: 50) == true)
        #expect(manager.canAddProfile(currentCount: 10) == true)
        #expect(manager.canUseTimerDuration(minutes: 999) == true)

        defaults.removeSuite(named: suiteName)
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var rawValue = 0

    var value: Int {
        lock.withLock { rawValue }
    }

    func increment() {
        lock.withLock {
            rawValue += 1
        }
    }
}

private actor ProductLoadCallCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}
