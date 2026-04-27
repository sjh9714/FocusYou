import XCTest
@testable import Focus_You

@MainActor
final class AppBlockerTests: XCTestCase {
    private var blocker: AppBlocker!

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            blocker = AppBlocker.shared
            blocker.deactivate()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            blocker.deactivate()
        }
        try await super.tearDown()
    }

    func testActivateWithEmptyBundleIdsIsNoop() {
        blocker.activate(bundleIds: [])
        // 빈 배열이면 차단 상태가 아님
        XCTAssertFalse(blocker.isMonitoringActive)
    }

    func testActivateStartsMonitoring() {
        blocker.activate(bundleIds: ["com.test.app"])
        XCTAssertTrue(blocker.isMonitoringActive)
    }

    func testDeactivateStopsMonitoring() {
        blocker.activate(bundleIds: ["com.test.app"])
        blocker.deactivate()
        XCTAssertFalse(blocker.isMonitoringActive)
    }

    func testMultipleActivateDeactivateCycles() {
        blocker.activate(bundleIds: ["com.test.app1"])
        blocker.deactivate()
        blocker.activate(bundleIds: ["com.test.app2"])
        XCTAssertTrue(blocker.isMonitoringActive)
        blocker.deactivate()
        XCTAssertFalse(blocker.isMonitoringActive)
    }
}
