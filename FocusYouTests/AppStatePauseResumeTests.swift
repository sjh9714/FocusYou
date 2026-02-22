import SwiftData
import XCTest
@testable import Focus_You

@MainActor
final class AppStatePauseResumeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(false, forKey: Constants.Settings.debugFastTimerEnabledKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: Constants.Settings.debugFastTimerEnabledKey)
        super.tearDown()
    }

    func testPauseSessionTransitionsToPaused() async throws {
        let appState = makeAppState()
        let modelContext = try makeModelContext()

        await appState.startFocusSession(
            duration: 300,
            sites: [],
            apps: [],
            modelContext: modelContext
        )
        XCTAssertEqual(appState.focusState, .focusing)

        appState.pauseSession()

        XCTAssertEqual(appState.focusState, .paused)
    }

    func testResumeSessionTransitionsBackToFocusing() async throws {
        let appState = makeAppState()
        let modelContext = try makeModelContext()

        await appState.startFocusSession(
            duration: 300,
            sites: [],
            apps: [],
            modelContext: modelContext
        )

        appState.pauseSession()
        XCTAssertEqual(appState.focusState, .paused)

        appState.resumeSession()
        XCTAssertEqual(appState.focusState, .focusing)
    }

    func testPauseWhileIdleDoesNothing() {
        let appState = makeAppState()
        XCTAssertEqual(appState.focusState, .idle)

        appState.pauseSession()

        XCTAssertEqual(appState.focusState, .idle)
    }

    func testResumeWhileFocusingDoesNothing() async throws {
        let appState = makeAppState()
        let modelContext = try makeModelContext()

        await appState.startFocusSession(
            duration: 300,
            sites: [],
            apps: [],
            modelContext: modelContext
        )
        XCTAssertEqual(appState.focusState, .focusing)

        appState.resumeSession()

        XCTAssertEqual(appState.focusState, .focusing)
    }

    func testStopSessionFromPausedTransitionsToIdle() async throws {
        let appState = makeAppState()
        let modelContext = try makeModelContext()

        await appState.startFocusSession(
            duration: 300,
            sites: [],
            apps: [],
            modelContext: modelContext
        )

        appState.pauseSession()
        XCTAssertEqual(appState.focusState, .paused)

        await appState.stopSession(modelContext: modelContext)
        XCTAssertEqual(appState.focusState, .idle)
    }

    func testStartFocusSessionWhileFocusingDoesNotRestart() async throws {
        let blockingCoordinator = MockBlockingCoordinator()
        let appState = AppState(
            blockingCoordinator: blockingCoordinator,
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

        // 이미 focusing인 상태에서 또 시작하면 무시해야 함
        await appState.startFocusSession(
            duration: 600,
            sites: [],
            apps: [],
            modelContext: modelContext
        )

        let counts = await blockingCoordinator.callCounts()
        XCTAssertEqual(counts.activate, 1, "두 번째 startFocusSession은 무시되어야 함")
    }

    func testResetToIdleClearsAllCompletionState() async throws {
        let appState = makeAppState()
        let modelContext = try makeModelContext()

        await appState.startFocusSession(
            duration: 60,
            sites: [],
            apps: [],
            modelContext: modelContext,
            mode: .pomodoro,
            pomodoroConfiguration: PomodoroConfiguration(
                focusMinutes: 1,
                shortBreakMinutes: 1,
                longBreakMinutes: 1,
                cycles: 1
            )
        )

        // 1차: focus 페이즈 완료 → longBreak 전환
        appState.timer.onComplete?()

        let didAdvanceToBreak = await waitUntil {
            appState.currentPomodoroPhase?.type == .longBreak
        }
        XCTAssertTrue(didAdvanceToBreak)

        // 2차: longBreak 완료 → 세션 완료
        appState.timer.onComplete?()

        let didComplete = await waitUntil {
            appState.focusState == .completed
        }
        XCTAssertTrue(didComplete)

        appState.resetToIdle()

        XCTAssertEqual(appState.focusState, .idle)
        XCTAssertNil(appState.completedSession)
        XCTAssertNil(appState.lastCompletedIntention)
        XCTAssertEqual(appState.lastCompletedXPEarned, 0)
        XCTAssertNil(appState.pendingLevelUp)
        XCTAssertNil(appState.lastCompletedStreakInfo)
    }

    func testDismissErrorClearsErrorState() {
        let appState = makeAppState()

        appState.errorMessage = "테스트 에러"
        appState.showError = true
        appState.canRetryBlockingDeactivation = true

        appState.dismissError()

        XCTAssertFalse(appState.showError)
        XCTAssertNil(appState.errorMessage)
        XCTAssertFalse(appState.canRetryBlockingDeactivation)
    }

    func testSaveRetrospectEmojiSetsEmojiOnCompletedSession() async throws {
        let appState = makeAppState()
        let modelContext = try makeModelContext()

        await appState.startFocusSession(
            duration: 60,
            sites: [],
            apps: [],
            modelContext: modelContext
        )

        appState.timer.onComplete?()

        let didComplete = await waitUntil {
            appState.focusState == .completed
        }
        XCTAssertTrue(didComplete)

        appState.saveRetrospectEmoji("🔥")
        XCTAssertEqual(appState.completedSession?.retrospectEmoji, "🔥")
    }

    func testSaveRetrospectFullSetsAllFields() async throws {
        let appState = makeAppState()
        let modelContext = try makeModelContext()

        await appState.startFocusSession(
            duration: 60,
            sites: [],
            apps: [],
            modelContext: modelContext
        )

        appState.timer.onComplete?()

        let didComplete = await waitUntil {
            appState.focusState == .completed
        }
        XCTAssertTrue(didComplete)

        appState.saveRetrospectFull(emoji: "💪", text: "잘했다!", rating: 5)
        XCTAssertEqual(appState.completedSession?.retrospectEmoji, "💪")
        XCTAssertEqual(appState.completedSession?.retrospectText, "잘했다!")
        XCTAssertEqual(appState.completedSession?.retrospectRating, 5)
    }

    // MARK: - Helpers

    private func makeAppState() -> AppState {
        AppState(
            blockingCoordinator: MockBlockingCoordinator(),
            notificationService: MockNotificationService(),
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: false
        )
    }

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

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }
}
