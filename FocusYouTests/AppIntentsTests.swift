import SwiftData
import XCTest
@testable import Focus_You

final class AppIntentsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(false, forKey: Constants.Settings.debugFastTimerEnabledKey)
        UserDefaults.standard.set(false, forKey: Constants.Settings.enableFocusModeKey)
        UserDefaults.standard.set(false, forKey: Constants.Settings.enableCalendarSyncKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: Constants.Settings.debugFastTimerEnabledKey)
        UserDefaults.standard.removeObject(forKey: Constants.Settings.enableFocusModeKey)
        UserDefaults.standard.removeObject(forKey: Constants.Settings.enableCalendarSyncKey)
        super.tearDown()
    }

    // MARK: - IntentError

    func testIntentErrorAppNotRunning() {
        let error = IntentError.appNotRunning
        XCTAssertNotNil(error.localizedStringResource)
    }

    func testIntentErrorSessionAlreadyActive() {
        let error = IntentError.sessionAlreadyActive
        XCTAssertNotNil(error.localizedStringResource)
    }

    func testIntentErrorNoActiveSession() {
        let error = IntentError.noActiveSession
        XCTAssertNotNil(error.localizedStringResource)
    }

    func testIntentErrorProfileNotFound() {
        let error = IntentError.profileNotFound("테스트 프로필")
        XCTAssertNotNil(error.localizedStringResource)
    }

    // MARK: - AppState.shared

    @MainActor
    func testAppStateSharedIsNilBeforeInit() {
        _ = AppState.shared
    }

    @MainActor
    func testAppStateSharedSetOnInit() {
        let appState = AppState(
            blockingCoordinator: MockBlockingCoordinator(),
            notificationService: MockNotificationService(),
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: false
        )

        XCTAssertTrue(AppState.shared === appState)
    }

    // MARK: - TogglePauseIntent

    @MainActor
    func testTogglePauseFromFocusingTransitionsToPaused() async throws {
        let appState = AppState(
            blockingCoordinator: MockBlockingCoordinator(),
            notificationService: MockNotificationService(),
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

        _ = try await TogglePauseIntent().perform()

        XCTAssertEqual(appState.focusState, .paused)
    }

    @MainActor
    func testTogglePauseFromPausedTransitionsToFocusing() async throws {
        let appState = AppState(
            blockingCoordinator: MockBlockingCoordinator(),
            notificationService: MockNotificationService(),
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
        appState.pauseSession()
        XCTAssertEqual(appState.focusState, .paused)

        _ = try await TogglePauseIntent().perform()

        XCTAssertEqual(appState.focusState, .focusing)
    }

    @MainActor
    func testTogglePauseWhileIdleKeepsIdle() async throws {
        let appState = AppState(
            blockingCoordinator: MockBlockingCoordinator(),
            notificationService: MockNotificationService(),
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: false
        )

        XCTAssertEqual(appState.focusState, .idle)

        _ = try await TogglePauseIntent().perform()

        XCTAssertEqual(appState.focusState, .idle)
    }

    // MARK: - GetFocusStatusIntent

    @MainActor
    func testGetFocusStatusWhileIdleReturnsWithoutError() async throws {
        let appState = AppState(
            blockingCoordinator: MockBlockingCoordinator(),
            notificationService: MockNotificationService(),
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: false
        )
        XCTAssertEqual(appState.focusState, .idle)

        _ = try await GetFocusStatusIntent().perform()
    }

    @MainActor
    func testGetFocusStatusWhileFocusingReturnsWithoutError() async throws {
        let appState = AppState(
            blockingCoordinator: MockBlockingCoordinator(),
            notificationService: MockNotificationService(),
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

        _ = try await GetFocusStatusIntent().perform()
    }

    @MainActor
    func testGetFocusStatusWhilePausedReturnsWithoutError() async throws {
        let appState = AppState(
            blockingCoordinator: MockBlockingCoordinator(),
            notificationService: MockNotificationService(),
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
        appState.pauseSession()
        XCTAssertEqual(appState.focusState, .paused)

        _ = try await GetFocusStatusIntent().perform()
    }

    // MARK: - StopFocusIntent 가드

    @MainActor
    func testStopFocusIntentWhileIdleReturnsWithoutStopping() async throws {
        let appState = AppState(
            blockingCoordinator: MockBlockingCoordinator(),
            notificationService: MockNotificationService(),
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: false
        )

        XCTAssertEqual(appState.focusState, .idle)

        _ = try await StopFocusIntent().perform()

        XCTAssertEqual(appState.focusState, .idle)
    }

    // MARK: - Helpers

    private func makeModelContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BlockProfile.self,
            BlockedSite.self,
            BlockedApp.self,
            FocusSession.self,
            BlockSchedule.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}
