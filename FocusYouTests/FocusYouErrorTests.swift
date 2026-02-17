import XCTest
@testable import Focus_You

final class FocusYouErrorTests: XCTestCase {
    func testAllErrorCasesHaveNonNilDescription() {
        let errors: [FocusYouError] = [
            .hostsFileAccessDenied,
            .hostsFileReadFailed,
            .hostsFileWriteFailed,
            .dnsFlushFailed,
            .appNotFound(bundleId: "com.example.app"),
            .appTerminationFailed(name: "ExampleApp"),
            .timerAlreadyRunning,
            .timerNotRunning,
            .blockingAlreadyActive,
            .authorizationFailed,
            .authorizationCancelled,
            .launchAgentInstallFailed,
            .presetLoadFailed(category: "social"),
            .networkExtensionNotInstalled,
            .networkExtensionActivationFailed,
            .networkExtensionDeactivationFailed,
        ]

        for error in errors {
            XCTAssertNotNil(
                error.errorDescription,
                "\(error) should have a non-nil errorDescription"
            )
            XCTAssertFalse(
                error.errorDescription!.isEmpty,
                "\(error) errorDescription should not be empty"
            )
        }
    }

    func testAppNotFoundIncludesBundleIdInDescription() {
        let error = FocusYouError.appNotFound(bundleId: "com.test.bundle")
        let description = error.errorDescription ?? ""
        XCTAssertTrue(
            description.contains("com.test.bundle"),
            "appNotFound description should contain the bundle ID"
        )
    }

    func testAppTerminationFailedIncludesNameInDescription() {
        let error = FocusYouError.appTerminationFailed(name: "Safari")
        let description = error.errorDescription ?? ""
        XCTAssertTrue(
            description.contains("Safari"),
            "appTerminationFailed description should contain the app name"
        )
    }

    func testPresetLoadFailedIncludesCategoryInDescription() {
        let error = FocusYouError.presetLoadFailed(category: "gaming")
        let description = error.errorDescription ?? ""
        XCTAssertTrue(
            description.contains("gaming"),
            "presetLoadFailed description should contain the category name"
        )
    }

    func testErrorConformsToLocalizedError() {
        let error: LocalizedError = FocusYouError.timerAlreadyRunning
        XCTAssertNotNil(error.errorDescription)
    }
}
