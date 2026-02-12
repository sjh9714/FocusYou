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
}
