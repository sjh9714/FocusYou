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

    func testCompletionSoundUsesDefaultWhenValueMissing() {
        XCTAssertEqual(
            NotificationService.shared.isCompletionSoundEnabled(),
            Constants.Settings.playCompletionSoundDefault
        )
    }

    func testCompletionSoundReadsStoredValue() {
        defaults.set(false, forKey: Constants.Settings.playCompletionSoundKey)
        XCTAssertFalse(NotificationService.shared.isCompletionSoundEnabled())
    }

    func testBlockingNotificationUsesDefaultWhenValueMissing() {
        XCTAssertEqual(
            NotificationService.shared.isBlockingEventNotificationEnabled(),
            Constants.Settings.showBlockedAppNotificationDefault
        )
    }

    func testBlockingNotificationReadsStoredValue() {
        defaults.set(false, forKey: Constants.Settings.showBlockedAppNotificationKey)
        XCTAssertFalse(NotificationService.shared.isBlockingEventNotificationEnabled())
    }

    private func clearKeys() {
        defaults.removeObject(forKey: Constants.Settings.playCompletionSoundKey)
        defaults.removeObject(forKey: Constants.Settings.showBlockedAppNotificationKey)
    }
}
