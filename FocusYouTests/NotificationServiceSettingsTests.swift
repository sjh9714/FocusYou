import XCTest
@testable import Focus_You

final class NotificationServiceSettingsTests: XCTestCase {
    private let defaults = UserDefaults.standard

    override func setUp() {
        super.setUp()
        clearKeys()
    }

    override func tearDown() {
        clearKeys()
        super.tearDown()
    }

    func testCompletionSoundUsesDefaultWhenValueMissing() async {
        let isEnabled = await NotificationService.shared.isCompletionSoundEnabled()
        XCTAssertEqual(isEnabled, Constants.Settings.playCompletionSoundDefault)
    }

    func testCompletionSoundReadsStoredValue() async {
        defaults.set(false, forKey: Constants.Settings.playCompletionSoundKey)
        let isEnabled = await NotificationService.shared.isCompletionSoundEnabled()
        XCTAssertFalse(isEnabled)
    }

    func testBlockingNotificationUsesDefaultWhenValueMissing() async {
        let isEnabled = await NotificationService.shared.isBlockingEventNotificationEnabled()
        XCTAssertEqual(isEnabled, Constants.Settings.showBlockedAppNotificationDefault)
    }

    func testBlockingNotificationReadsStoredValue() async {
        defaults.set(false, forKey: Constants.Settings.showBlockedAppNotificationKey)
        let isEnabled = await NotificationService.shared.isBlockingEventNotificationEnabled()
        XCTAssertFalse(isEnabled)
    }

    private func clearKeys() {
        defaults.removeObject(forKey: Constants.Settings.playCompletionSoundKey)
        defaults.removeObject(forKey: Constants.Settings.showBlockedAppNotificationKey)
    }
}
