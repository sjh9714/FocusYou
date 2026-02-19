import XCTest
@testable import Focus_You

final class FocusModeControllerTests: XCTestCase {

    @MainActor
    func testSingletonInstance() {
        let controller = FocusModeController.shared
        XCTAssertNotNil(controller)
        XCTAssertTrue(controller === FocusModeController.shared)
    }

    @MainActor
    func testInitialStateIsInactive() {
        let controller = FocusModeController.shared
        XCTAssertFalse(controller.isDNDActivatedByApp)
    }

    // MARK: - Settings Constants

    func testFocusModeSettingsKey() {
        XCTAssertEqual(Constants.Settings.enableFocusModeKey, "enableFocusMode")
        XCTAssertFalse(Constants.Settings.enableFocusModeDefault)
    }
}
