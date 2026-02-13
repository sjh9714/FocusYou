import SwiftData
import XCTest
@testable import Focus_You

@MainActor
final class AppStateLifecycleTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: Constants.Settings.strictBrowserBlockingKey)
        super.tearDown()
    }

    func testStartAndStopSessionTransitionsToIdleAndCancelsSession() async throws {
        let blockingCoordinator = MockBlockingCoordinator()
        let notificationService = MockNotificationService()
        let appState = AppState(
            blockingCoordinator: blockingCoordinator,
            notificationService: notificationService,
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: false
        )
        let modelContext = try makeModelContext()

        await appState.startFocusSession(
            duration: 300,
            sites: [],
            apps: [],
            modelContext: modelContext
        )

        XCTAssertEqual(appState.focusState, .focusing)
        XCTAssertNotNil(appState.currentSession)

        let recordedSession = try XCTUnwrap(appState.currentSession)
        await appState.stopSession(modelContext: modelContext)

        XCTAssertEqual(appState.focusState, .idle)
        XCTAssertNil(appState.currentSession)
        XCTAssertFalse(recordedSession.wasCompleted)
        XCTAssertNotNil(recordedSession.endedAt)

        let counts = await blockingCoordinator.callCounts()
        XCTAssertEqual(counts.activate, 1)
        XCTAssertEqual(counts.deactivate, 1)
    }

    func testTimerCompletionTransitionsToCompletedAndCompletesSession() async throws {
        let blockingCoordinator = MockBlockingCoordinator()
        let notificationService = MockNotificationService()
        let appState = AppState(
            blockingCoordinator: blockingCoordinator,
            notificationService: notificationService,
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: false
        )
        let modelContext = try makeModelContext()

        await appState.startFocusSession(
            duration: 120,
            sites: [],
            apps: [],
            modelContext: modelContext
        )
        let recordedSession = try XCTUnwrap(appState.currentSession)

        appState.timer.onComplete?()

        let completed = await waitUntil {
            appState.focusState == .completed && appState.currentSession == nil
        }

        XCTAssertTrue(completed)
        XCTAssertTrue(recordedSession.wasCompleted)
        XCTAssertEqual(recordedSession.actualDuration, 120)
        XCTAssertEqual(appState.focusState, .completed)
        XCTAssertFalse(appState.isBlockingActive)
        XCTAssertEqual(appState.lastCompletedMode, .free)
        XCTAssertEqual(appState.lastCompletedFocusDuration, 120)

        let counts = await blockingCoordinator.callCounts()
        XCTAssertEqual(counts.deactivate, 1)

        let timerCompletedDurations = await notificationService.timerCompletedDurationsSnapshot()
        XCTAssertEqual(timerCompletedDurations, [120])
    }

    func testCompletionThenResetReturnsToIdleAndClearsCompletionSnapshot() async throws {
        let appState = AppState(
            blockingCoordinator: MockBlockingCoordinator(),
            notificationService: MockNotificationService(),
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: false
        )
        let modelContext = try makeModelContext()

        await appState.startFocusSession(
            duration: 90,
            sites: [],
            apps: [],
            modelContext: modelContext
        )

        appState.timer.onComplete?()

        let didComplete = await waitUntil {
            appState.focusState == .completed
        }
        XCTAssertTrue(didComplete)
        XCTAssertEqual(appState.lastCompletedFocusDuration, 90)
        XCTAssertEqual(appState.lastCompletedMode, .free)

        appState.resetToIdle()

        XCTAssertEqual(appState.focusState, .idle)
        XCTAssertFalse(appState.isBlockingActive)
        XCTAssertEqual(appState.timerMode, .free)
        XCTAssertEqual(appState.lastCompletedFocusDuration, 0)
        XCTAssertEqual(appState.lastCompletedPomodoroCycles, 0)
        XCTAssertEqual(appState.lastCompletedPomodoroBreakDuration, 0)
    }

    func testStopSessionDeactivationFailureKeepsRetrySignalAndRetryRecovers() async throws {
        let blockingCoordinator = MockBlockingCoordinator()
        let notificationService = MockNotificationService()
        let appState = AppState(
            blockingCoordinator: blockingCoordinator,
            notificationService: notificationService,
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: false
        )
        let modelContext = try makeModelContext()

        let blockedSite = BlockedSite(domain: "example.com")

        await appState.startFocusSession(
            duration: 180,
            sites: [blockedSite],
            apps: [],
            modelContext: modelContext
        )
        XCTAssertTrue(appState.isBlockingActive)

        await blockingCoordinator.setDeactivateError(FocusYouError.hostsFileWriteFailed)
        await appState.stopSession(modelContext: modelContext)

        XCTAssertEqual(appState.focusState, .idle)
        XCTAssertTrue(appState.showError)
        XCTAssertTrue(appState.canRetryBlockingDeactivation)
        XCTAssertTrue(appState.isBlockingActive)

        await blockingCoordinator.setDeactivateError(nil)
        await appState.retryBlockingDeactivation()

        XCTAssertFalse(appState.showError)
        XCTAssertFalse(appState.canRetryBlockingDeactivation)
        XCTAssertFalse(appState.isBlockingActive)

        let counts = await blockingCoordinator.callCounts()
        XCTAssertEqual(counts.deactivate, 2)
    }

    func testStartFocusSessionAddsStrictBrowserBundleIDsWhenEnabled() async throws {
        UserDefaults.standard.set(true, forKey: Constants.Settings.strictBrowserBlockingKey)

        let blockingCoordinator = MockBlockingCoordinator()
        let appState = AppState(
            blockingCoordinator: blockingCoordinator,
            notificationService: MockNotificationService(),
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: false
        )
        let modelContext = try makeModelContext()
        let site = BlockedSite(domain: "fmkorea.com")

        await appState.startFocusSession(
            duration: 120,
            sites: [site],
            apps: [],
            modelContext: modelContext
        )

        let args = await blockingCoordinator.latestActivateArguments()
        XCTAssertEqual(args?.domains, ["fmkorea.com"])
        XCTAssertEqual(args?.appBundleIds ?? [], Constants.Blocking.strictBrowserBundleIDs.sorted())
    }

    func testStartFocusSessionDoesNotAddStrictBrowserBundleIDsWhenDisabled() async throws {
        UserDefaults.standard.set(false, forKey: Constants.Settings.strictBrowserBlockingKey)

        let blockingCoordinator = MockBlockingCoordinator()
        let appState = AppState(
            blockingCoordinator: blockingCoordinator,
            notificationService: MockNotificationService(),
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: false
        )
        let modelContext = try makeModelContext()
        let site = BlockedSite(domain: "fmkorea.com")

        await appState.startFocusSession(
            duration: 120,
            sites: [site],
            apps: [],
            modelContext: modelContext
        )

        let args = await blockingCoordinator.latestActivateArguments()
        XCTAssertEqual(args?.domains, ["fmkorea.com"])
        XCTAssertEqual(args?.appBundleIds ?? [], [])
    }

    func testStartupCleanupErrorPresentsRetryableError() async {
        let blockingCoordinator = MockBlockingCoordinator()
        await blockingCoordinator.setEmergencyCleanupResult(.error(.hostsFileWriteFailed))

        let appState = AppState(
            blockingCoordinator: blockingCoordinator,
            notificationService: MockNotificationService(),
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: true
        )

        let didShowError = await waitUntil {
            appState.showError
        }

        XCTAssertTrue(didShowError)
        XCTAssertTrue(appState.canRetryBlockingDeactivation)
        XCTAssertTrue(appState.errorMessage?.contains("앱 시작 시 차단 복구에 실패했습니다.") == true)

        let counts = await blockingCoordinator.callCounts()
        XCTAssertEqual(counts.cleanup, 1)
    }

    func testStartupCleanupSuccessKeepsIdleStateWithoutError() async {
        let blockingCoordinator = MockBlockingCoordinator()
        await blockingCoordinator.setEmergencyCleanupResult(.idle)

        let appState = AppState(
            blockingCoordinator: blockingCoordinator,
            notificationService: MockNotificationService(),
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: true
        )

        let didRunCleanup = await waitUntilAsync {
            let counts = await blockingCoordinator.callCounts()
            return counts.cleanup == 1
        }

        XCTAssertTrue(didRunCleanup)
        XCTAssertEqual(appState.focusState, .idle)
        XCTAssertFalse(appState.isBlockingActive)
        XCTAssertFalse(appState.showError)
        XCTAssertFalse(appState.canRetryBlockingDeactivation)
        XCTAssertNil(appState.errorMessage)
    }

    private func makeModelContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: FocusSession.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        intervalNanoseconds: UInt64 = 20_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }

        return condition()
    }

    private func waitUntilAsync(
        timeout: TimeInterval = 1.0,
        intervalNanoseconds: UInt64 = 20_000_000,
        condition: @escaping () async -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if await condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }

        return await condition()
    }
}

actor MockBlockingCoordinator: BlockingCoordinating {
    private(set) var state: BlockingCoordinator.State = .idle
    private(set) var activateCallCount = 0
    private(set) var deactivateCallCount = 0
    private(set) var emergencyCleanupCallCount = 0

    private var activateError: Error?
    private var deactivateError: Error?
    private var emergencyCleanupResult: BlockingCoordinator.State = .idle
    private var lastActivateDomains: [String] = []
    private var lastActivateAppBundleIDs: [String] = []

    func activateBlocking(domains: [String], appBundleIds: [String]) async throws {
        activateCallCount += 1
        lastActivateDomains = domains
        lastActivateAppBundleIDs = appBundleIds.sorted()
        if let activateError {
            state = .error((activateError as? FocusYouError) ?? .hostsFileWriteFailed)
            throw activateError
        }

        state = (domains.isEmpty && appBundleIds.isEmpty) ? .idle : .blocking
    }

    func deactivateBlocking() async throws {
        deactivateCallCount += 1
        if let deactivateError {
            state = .error((deactivateError as? FocusYouError) ?? .hostsFileWriteFailed)
            throw deactivateError
        }

        state = .idle
    }

    func emergencyCleanup() async {
        emergencyCleanupCallCount += 1
        state = emergencyCleanupResult
    }

    func setDeactivateError(_ error: Error?) {
        deactivateError = error
    }

    func setEmergencyCleanupResult(_ result: BlockingCoordinator.State) {
        emergencyCleanupResult = result
    }

    func callCounts() -> (activate: Int, deactivate: Int, cleanup: Int) {
        (
            activate: activateCallCount,
            deactivate: deactivateCallCount,
            cleanup: emergencyCleanupCallCount
        )
    }

    func latestActivateArguments() -> (domains: [String], appBundleIds: [String])? {
        guard activateCallCount > 0 else { return nil }
        return (domains: lastActivateDomains, appBundleIds: lastActivateAppBundleIDs)
    }
}

actor MockNotificationService: NotificationServicing {
    private(set) var requestPermissionCallCount = 0
    private(set) var timerCompletedDurations = [TimeInterval]()
    private(set) var appBlockedNames = [String]()
    private(set) var blockingDeactivatedCount = 0
    private(set) var pomodoroPhaseNotifications = [(phaseTitle: String, cycleText: String)]()

    func requestPermission() async -> Bool {
        requestPermissionCallCount += 1
        return true
    }

    func sendTimerCompleted(duration: TimeInterval) async {
        timerCompletedDurations.append(duration)
    }

    func sendAppBlocked(appName: String) async {
        appBlockedNames.append(appName)
    }

    func sendBlockingDeactivated() async {
        blockingDeactivatedCount += 1
    }

    func sendPomodoroPhaseStarted(phaseTitle: String, cycleText: String) async {
        pomodoroPhaseNotifications.append((phaseTitle: phaseTitle, cycleText: cycleText))
    }

    func timerCompletedDurationsSnapshot() -> [TimeInterval] {
        timerCompletedDurations
    }
}
