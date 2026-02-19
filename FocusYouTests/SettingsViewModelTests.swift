import XCTest
@testable import Focus_You

final class SettingsViewModelTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "FocusYouTests.Settings.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    @MainActor
    func testDefaultsLoadWhenKeysAreMissing() {
        let viewModel = SettingsViewModel(defaults: defaults)

        XCTAssertEqual(viewModel.showMenuBarTime, Constants.Settings.showMenuBarTimeDefault)
        XCTAssertEqual(viewModel.playCompletionSound, Constants.Settings.playCompletionSoundDefault)
        XCTAssertEqual(
            viewModel.showBlockedAppNotification,
            Constants.Settings.showBlockedAppNotificationDefault
        )
        #if DEBUG
        XCTAssertEqual(viewModel.debugFastTimerEnabled, Constants.Settings.debugFastTimerEnabledDefault)
        XCTAssertEqual(
            viewModel.debugSecondsPerMinute,
            Constants.Settings.debugSecondsPerMinuteDefault
        )
        #endif
    }

    @MainActor
    func testUpdatedValuesPersistAcrossNewViewModelInstance() {
        let firstViewModel = SettingsViewModel(defaults: defaults)
        firstViewModel.showMenuBarTime = false
        firstViewModel.playCompletionSound = false
        firstViewModel.showBlockedAppNotification = false

        #if DEBUG
        firstViewModel.debugFastTimerEnabled = true
        firstViewModel.debugSecondsPerMinute = 7
        #endif

        let secondViewModel = SettingsViewModel(defaults: defaults)

        XCTAssertFalse(secondViewModel.showMenuBarTime)
        XCTAssertFalse(secondViewModel.playCompletionSound)
        XCTAssertFalse(secondViewModel.showBlockedAppNotification)

        #if DEBUG
        XCTAssertTrue(secondViewModel.debugFastTimerEnabled)
        XCTAssertEqual(secondViewModel.debugSecondsPerMinute, 7)
        #endif
    }

    // MARK: - 온보딩

    @MainActor
    func testOnboardingDefaultIsFalse() {
        let viewModel = SettingsViewModel(defaults: defaults)
        XCTAssertFalse(viewModel.hasCompletedOnboarding)
    }

    @MainActor
    func testOnboardingPersistsAcrossInstances() {
        let first = SettingsViewModel(defaults: defaults)
        first.hasCompletedOnboarding = true

        let second = SettingsViewModel(defaults: defaults)
        XCTAssertTrue(second.hasCompletedOnboarding)
    }

    // MARK: - 의도 입력 & 회고 (v1.1)

    @MainActor
    func testIntentionInputDefaultIsFalse() {
        let viewModel = SettingsViewModel(defaults: defaults)
        XCTAssertFalse(viewModel.showIntentionInput)
    }

    @MainActor
    func testRetrospectDefaultIsFalse() {
        let viewModel = SettingsViewModel(defaults: defaults)
        XCTAssertFalse(viewModel.showRetrospect)
    }

    @MainActor
    func testIntentionAndRetrospectPersist() {
        let first = SettingsViewModel(defaults: defaults)
        first.showIntentionInput = true
        first.showRetrospect = true

        let second = SettingsViewModel(defaults: defaults)
        XCTAssertTrue(second.showIntentionInput)
        XCTAssertTrue(second.showRetrospect)
    }

    // MARK: - 로그인 시 자동 시작 (v1.2)

    @MainActor
    func testLaunchAtLoginDefaultsOff() {
        let viewModel = SettingsViewModel(defaults: defaults)
        XCTAssertFalse(viewModel.launchAtLogin)
    }

    // MARK: - Apple Calendar 동기화 (v1.3)

    @MainActor
    func testCalendarSyncDefaultsOff() {
        let viewModel = SettingsViewModel(defaults: defaults)
        XCTAssertFalse(viewModel.enableCalendarSync)
    }

    @MainActor
    func testCalendarSyncPersists() {
        let first = SettingsViewModel(defaults: defaults)
        first.enableCalendarSync = true

        let second = SettingsViewModel(defaults: defaults)
        XCTAssertTrue(second.enableCalendarSync)
    }

    // MARK: - 스케줄 (v1.3)

    @MainActor
    func testScheduleDefaultsOff() {
        let viewModel = SettingsViewModel(defaults: defaults)
        XCTAssertFalse(viewModel.enableSchedule)
    }

    @MainActor
    func testSchedulePersists() {
        let first = SettingsViewModel(defaults: defaults)
        first.enableSchedule = true

        let second = SettingsViewModel(defaults: defaults)
        XCTAssertTrue(second.enableSchedule)
    }

    // MARK: - Focus Mode (v1.4)

    @MainActor
    func testFocusModeDefaultsOff() {
        let viewModel = SettingsViewModel(defaults: defaults)
        XCTAssertFalse(viewModel.enableFocusMode)
    }

    @MainActor
    func testFocusModePersists() {
        let first = SettingsViewModel(defaults: defaults)
        first.enableFocusMode = true

        let second = SettingsViewModel(defaults: defaults)
        XCTAssertTrue(second.enableFocusMode)
    }

    // MARK: - 회고 레벨 (v1.5)

    @MainActor
    func testRetrospectLevelDefault() {
        let viewModel = SettingsViewModel(defaults: defaults)
        XCTAssertEqual(viewModel.retrospectLevel, 1)
    }

    @MainActor
    func testRetrospectLevelPersists() {
        let first = SettingsViewModel(defaults: defaults)
        first.retrospectLevel = 3

        let second = SettingsViewModel(defaults: defaults)
        XCTAssertEqual(second.retrospectLevel, 3)
    }

    @MainActor
    func testRetrospectLevelClampsToRange() {
        let viewModel = SettingsViewModel(defaults: defaults)
        viewModel.retrospectLevel = 0
        XCTAssertEqual(viewModel.retrospectLevel, 1)

        viewModel.retrospectLevel = 5
        XCTAssertEqual(viewModel.retrospectLevel, 3)
    }

    // MARK: - 번아웃 방지 (v1.5)

    @MainActor
    func testBurnoutWarningsDefaultsOff() {
        let viewModel = SettingsViewModel(defaults: defaults)
        XCTAssertFalse(viewModel.enableBurnoutWarnings)
    }

    @MainActor
    func testBurnoutWarningsPersists() {
        let first = SettingsViewModel(defaults: defaults)
        first.enableBurnoutWarnings = true

        let second = SettingsViewModel(defaults: defaults)
        XCTAssertTrue(second.enableBurnoutWarnings)
    }

    @MainActor
    func testBurnoutDailyLimitDefault() {
        let viewModel = SettingsViewModel(defaults: defaults)
        XCTAssertEqual(viewModel.burnoutDailyLimitHours, 6.0, accuracy: 0.01)
    }

    @MainActor
    func testBurnoutDailyLimitPersists() {
        let first = SettingsViewModel(defaults: defaults)
        first.burnoutDailyLimitHours = 8.0

        let second = SettingsViewModel(defaults: defaults)
        XCTAssertEqual(second.burnoutDailyLimitHours, 8.0, accuracy: 0.01)
    }

    @MainActor
    func testBurnoutDailyLimitClampsToRange() {
        let viewModel = SettingsViewModel(defaults: defaults)
        viewModel.burnoutDailyLimitHours = 1.0  // below min 2
        XCTAssertEqual(viewModel.burnoutDailyLimitHours, 2.0, accuracy: 0.01)

        viewModel.burnoutDailyLimitHours = 15.0  // above max 12
        XCTAssertEqual(viewModel.burnoutDailyLimitHours, 12.0, accuracy: 0.01)
    }
}
