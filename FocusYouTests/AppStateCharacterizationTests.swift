import SwiftData
import XCTest
@testable import Focus_You

@MainActor
final class AppStateCharacterizationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(false, forKey: Constants.Settings.debugFastTimerEnabledKey)
        UserDefaults.standard.set(false, forKey: Constants.Settings.enableFocusModeKey)
        UserDefaults.standard.set(false, forKey: Constants.Settings.enableCalendarSyncKey)
        UserDefaults.standard.removeObject(forKey: "emergencyUnlockLastUsedDate")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: Constants.Settings.debugFastTimerEnabledKey)
        UserDefaults.standard.removeObject(forKey: Constants.Settings.enableFocusModeKey)
        UserDefaults.standard.removeObject(forKey: Constants.Settings.enableCalendarSyncKey)
        UserDefaults.standard.removeObject(forKey: "emergencyUnlockLastUsedDate")
        super.tearDown()
    }

    func testPomodoroFullCycleCompletionPreservesSnapshotAndBlockingTransitions() async throws {
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
            duration: 60,
            sites: [blockedSite],
            apps: [],
            modelContext: modelContext,
            mode: .pomodoro,
            pomodoroConfiguration: PomodoroConfiguration(
                focusMinutes: 1,
                shortBreakMinutes: 1,
                longBreakMinutes: 2,
                cycles: 2
            )
        )

        XCTAssertEqual(appState.currentPomodoroPhase?.type, .focus)
        XCTAssertTrue(appState.isBlockingActive)

        appState.timer.onComplete?()
        let didReachShortBreak = await waitUntil {
            appState.currentPomodoroPhase?.type == .shortBreak
        }
        XCTAssertTrue(didReachShortBreak)
        XCTAssertFalse(appState.isBlockingActive)

        appState.timer.onComplete?()
        let didReachSecondFocus = await waitUntil {
            appState.currentPomodoroPhase?.type == .focus && appState.isBlockingActive
        }
        XCTAssertTrue(didReachSecondFocus)

        appState.timer.onComplete?()
        let didReachLongBreak = await waitUntil {
            appState.currentPomodoroPhase?.type == .longBreak
        }
        XCTAssertTrue(didReachLongBreak)
        XCTAssertFalse(appState.isBlockingActive)

        appState.timer.onComplete?()
        let didComplete = await waitUntil {
            appState.focusState == .completed
        }
        XCTAssertTrue(didComplete)

        XCTAssertEqual(appState.lastCompletedMode, .pomodoro)
        XCTAssertEqual(appState.lastCompletedFocusDuration, 120)
        XCTAssertEqual(appState.lastCompletedPomodoroCycles, 2)
        XCTAssertEqual(appState.lastCompletedPomodoroBreakDuration, 180)
        XCTAssertTrue(try XCTUnwrap(appState.completedSession).wasCompleted)
        XCTAssertNil(appState.currentSession)

        let counts = await blockingCoordinator.callCounts()
        XCTAssertEqual(counts.activate, 2)
        XCTAssertEqual(counts.deactivate, 3)
        let timerCompletedDurations = await notificationService.timerCompletedDurationsSnapshot()
        XCTAssertEqual(timerCompletedDurations, [120])
    }

    func testFlowmodoroFocusRestCompletionPreservesSnapshot() async throws {
        let appState = AppState(
            blockingCoordinator: MockBlockingCoordinator(),
            notificationService: MockNotificationService(),
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: false
        )
        let modelContext = try makeModelContext()

        await appState.startFocusSession(
            duration: Constants.Timer.flowmodoroMaxDuration,
            sites: [],
            apps: [],
            modelContext: modelContext,
            mode: .flowmodoro
        )

        XCTAssertEqual(appState.currentFlowmodoroPhase, .focus)
        await appState.finishFlowmodoroFocus(modelContext: modelContext)

        XCTAssertEqual(appState.currentFlowmodoroPhase, .rest)
        XCTAssertEqual(appState.focusState, .focusing)

        appState.timer.onComplete?()
        let didComplete = await waitUntil {
            appState.focusState == .completed
        }
        XCTAssertTrue(didComplete)

        XCTAssertEqual(appState.lastCompletedMode, .flowmodoro)
        XCTAssertEqual(appState.lastCompletedFlowmodoroBreakDuration, 1)
        XCTAssertTrue(try XCTUnwrap(appState.completedSession).wasCompleted)
    }

    func testScheduleRejoinConsumesPendingInfoAndStartsProfileSession() async throws {
        let appState = AppState(
            blockingCoordinator: MockBlockingCoordinator(),
            notificationService: MockNotificationService(),
            shouldRequestNotificationPermission: false,
            shouldRunStartupCleanup: false
        )
        let modelContext = try makeModelContext()
        let profile = BlockProfile(name: "Scheduled")
        modelContext.insert(profile)

        let nextMinute = (Calendar.current.component(.hour, from: Date()) * 60
            + Calendar.current.component(.minute, from: Date())
            + 1) % (24 * 60)
        appState.pendingScheduleRejoin = AppState.PendingScheduleInfo(
            scheduleName: "Morning",
            profileID: profile.persistentModelID,
            endMinuteOfDay: nextMinute,
            endTimeFormatted: "soon"
        )

        await appState.rejoinPendingSchedule(modelContext: modelContext)

        XCTAssertNil(appState.pendingScheduleRejoin)
        XCTAssertEqual(appState.activeScheduleName, "Morning")
        XCTAssertEqual(appState.focusState, .focusing)
        XCTAssertEqual(appState.currentSession?.profileName, "Scheduled")
        XCTAssertLessThanOrEqual(appState.timer.totalDuration, 60)
        XCTAssertGreaterThan(appState.timer.totalDuration, 0)
    }

    func testCancelIntensityStateResetsAfterStop() async throws {
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
            modelContext: modelContext,
            cancelIntensity: 2,
            cancelLockoutMinutes: 7
        )

        XCTAssertFalse(appState.canCancel)
        appState.requestEmergencyUnlock()
        XCTAssertTrue(appState.isEmergencyUnlockActive)
        XCTAssertEqual(appState.emergencyUnlockCountdown, Constants.CancelIntensity.emergencyUnlockDuration)

        await appState.stopSession(modelContext: modelContext)

        XCTAssertEqual(appState.currentCancelIntensity, 0)
        XCTAssertEqual(appState.currentCancelLockoutMinutes, 0)
        XCTAssertFalse(appState.isEmergencyUnlockActive)
        XCTAssertEqual(appState.emergencyUnlockCountdown, 0)
        XCTAssertTrue(appState.canCancel)
    }

    private func makeModelContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BlockProfile.self,
            BlockedSite.self,
            BlockedApp.self,
            FocusSession.self,
            BlockSchedule.self,
            Badge.self,
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
}
