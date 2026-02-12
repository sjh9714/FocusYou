import XCTest
@testable import Focus_You

final class BlockingCoordinatorTests: XCTestCase {
    func testActivateBlockingWithDomainsSetsBlockingState() async throws {
        let websiteBlocker = MockWebsiteBlocker()
        let coordinator = BlockingCoordinator(
            websiteBlocker: websiteBlocker,
            managesSafetyNet: false
        )

        try await coordinator.activateBlocking(
            domains: ["example.com", "github.com"],
            appBundleIds: []
        )

        let state = await coordinator.state
        guard case .blocking = state else {
            return XCTFail("Expected blocking state after activation")
        }

        let snapshot = await websiteBlocker.snapshot()
        XCTAssertEqual(snapshot.activateCallDomains.count, 1)
        XCTAssertEqual(snapshot.activateCallDomains.first ?? [], ["example.com", "github.com"])
        XCTAssertEqual(snapshot.deactivateCallCount, 0)
        XCTAssertTrue(snapshot.active)
    }

    func testDeactivateBlockingReturnsIdleAfterWebsiteCleanup() async throws {
        let websiteBlocker = MockWebsiteBlocker()
        let coordinator = BlockingCoordinator(
            websiteBlocker: websiteBlocker,
            managesSafetyNet: false
        )

        try await coordinator.activateBlocking(domains: ["example.com"], appBundleIds: [])
        try await coordinator.deactivateBlocking()

        let state = await coordinator.state
        guard case .idle = state else {
            return XCTFail("Expected idle state after deactivation")
        }

        let snapshot = await websiteBlocker.snapshot()
        XCTAssertEqual(snapshot.deactivateCallCount, 1)
        XCTAssertFalse(snapshot.active)
    }

    func testDeactivateBlockingFailureSetsErrorState() async throws {
        let websiteBlocker = MockWebsiteBlocker()
        let coordinator = BlockingCoordinator(
            websiteBlocker: websiteBlocker,
            managesSafetyNet: false
        )

        try await coordinator.activateBlocking(domains: ["example.com"], appBundleIds: [])
        await websiteBlocker.setShouldFailDeactivation(true)

        do {
            try await coordinator.deactivateBlocking()
            XCTFail("Expected deactivateBlocking to throw")
        } catch {
            // expected
        }

        let state = await coordinator.state
        switch state {
        case .error(let focusError):
            guard case .hostsFileWriteFailed = focusError else {
                return XCTFail("Expected hostsFileWriteFailed, got \(focusError.localizedDescription)")
            }
        default:
            XCTFail("Expected error state after deactivation failure")
        }

        let snapshot = await websiteBlocker.snapshot()
        XCTAssertEqual(snapshot.deactivateCallCount, 1)
    }

    func testDeactivateBlockingSkipsWebsiteWhenNotActive() async throws {
        let websiteBlocker = MockWebsiteBlocker()
        let coordinator = BlockingCoordinator(
            websiteBlocker: websiteBlocker,
            managesSafetyNet: false
        )

        try await coordinator.deactivateBlocking()

        let state = await coordinator.state
        guard case .idle = state else {
            return XCTFail("Expected idle state when deactivating inactive coordinator")
        }

        let snapshot = await websiteBlocker.snapshot()
        XCTAssertEqual(snapshot.deactivateCallCount, 0)
        XCTAssertFalse(snapshot.active)
    }
}

actor MockWebsiteBlocker: WebsiteBlocker {
    struct Snapshot: Sendable {
        let activateCallDomains: [[String]]
        let deactivateCallCount: Int
        let active: Bool
    }

    private var activateCallDomains = [[String]]()
    private var deactivateCallCount = 0
    private var active = false
    private var shouldFailDeactivation = false

    func activate(domains: [String]) async throws {
        activateCallDomains.append(domains)
        active = true
    }

    func deactivate() async throws {
        deactivateCallCount += 1
        if shouldFailDeactivation {
            throw FocusYouError.hostsFileWriteFailed
        }
        active = false
    }

    func isActive() async -> Bool {
        active
    }

    func setShouldFailDeactivation(_ value: Bool) {
        shouldFailDeactivation = value
    }

    func snapshot() -> Snapshot {
        Snapshot(
            activateCallDomains: activateCallDomains,
            deactivateCallCount: deactivateCallCount,
            active: active
        )
    }
}
