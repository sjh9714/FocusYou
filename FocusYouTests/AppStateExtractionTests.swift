import SwiftData
import XCTest
@testable import Focus_You

@MainActor
final class AppStateExtractionTests: XCTestCase {
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

    func testSessionTimingCalculatorMatchesCurrentDurationRules() {
        let calculator = SessionTimingCalculator()
        let pomodoroConfig = PomodoroConfiguration(
            focusMinutes: 25,
            shortBreakMinutes: 5,
            longBreakMinutes: 15,
            cycles: 4
        )

        XCTAssertEqual(
            calculator.plannedDuration(
                mode: .free,
                freeDuration: 600,
                pomodoroConfiguration: pomodoroConfig
            ),
            600
        )
        XCTAssertEqual(
            calculator.plannedDuration(
                mode: .pomodoro,
                freeDuration: 600,
                pomodoroConfiguration: pomodoroConfig
            ),
            6000
        )
        XCTAssertNil(
            calculator.plannedDuration(
                mode: .flowmodoro,
                freeDuration: 600,
                pomodoroConfiguration: pomodoroConfig
            )
        )
        XCTAssertEqual(
            calculator.pomodoroBreakDuration(configuration: pomodoroConfig),
            1800
        )
    }

    func testSessionTargetResolverFiltersDisabledTargetsAndExpandsKeywords() {
        let resolver = SessionTargetResolver()
        let keyword = BlockedSite(domain: "video", isKeywordPattern: true)
        let enabledSite = BlockedSite(domain: "example.com")
        let disabledSite = BlockedSite(domain: "ignore.com")
        disabledSite.isEnabled = false

        let enabledApp = BlockedApp(bundleId: "com.focusyou.enabled", name: "Enabled")
        let disabledApp = BlockedApp(bundleId: "com.focusyou.disabled", name: "Disabled")
        disabledApp.isEnabled = false

        let targets = resolver.resolve(
            sites: [keyword, enabledSite, disabledSite],
            apps: [enabledApp, disabledApp],
            blocklistMode: "allowlist"
        )

        XCTAssertEqual(targets.blocklistMode, "allowlist")
        XCTAssertEqual(Set(targets.domains), Set([
            "video.com",
            "video.net",
            "video.org",
            "video.io",
            "video.co",
            "example.com",
        ]))
        XCTAssertEqual(targets.appBundleIds, ["com.focusyou.enabled"])
        XCTAssertTrue(targets.hasBlockingTargets)
    }

    func testProfileSessionMapperMatchesCurrentProfileStartRules() {
        let mapper = ProfileSessionMapper()
        let profile = BlockProfile(name: "Deep Work")
        profile.timerMode = "pomodoro"
        profile.focusDuration = 20 * 60
        profile.breakDuration = 4 * 60
        profile.longBreakDuration = 12 * 60
        profile.pomodoroCount = 3
        profile.blocklistMode = "allowlist"
        profile.cancelIntensity = 2
        profile.cancelLockoutMinutes = 9

        let input = mapper.makeInput(from: profile)

        XCTAssertEqual(input.mode, .pomodoro)
        XCTAssertEqual(input.duration, 20 * 60)
        XCTAssertEqual(input.pomodoroConfiguration.focusMinutes, 20)
        XCTAssertEqual(input.pomodoroConfiguration.shortBreakMinutes, 4)
        XCTAssertEqual(input.pomodoroConfiguration.longBreakMinutes, 12)
        XCTAssertEqual(input.pomodoroConfiguration.cycles, 3)
        XCTAssertEqual(input.blocklistMode, "allowlist")
        XCTAssertEqual(input.cancelIntensity, 2)
        XCTAssertEqual(input.cancelLockoutMinutes, 9)
    }

    func testSessionProgressEvaluatorProducesCompletionCelebrationSnapshot() throws {
        let context = try makeModelContext()
        let previousSession = FocusSession(plannedDuration: 25 * 60)
        previousSession.complete(actualDuration: 25 * 60)
        context.insert(previousSession)

        let completedSession = FocusSession(plannedDuration: 25 * 60)
        completedSession.complete(actualDuration: 25 * 60)
        context.insert(completedSession)

        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        let evaluation = SessionProgressEvaluator().evaluate(
            allSessions: sessions,
            completedSession: completedSession,
            previousLevel: 1
        )

        XCTAssertEqual(evaluation.xpEarned, 32)
        XCTAssertEqual(evaluation.nextPreviousLevel, 2)
        XCTAssertEqual(evaluation.pendingLevelUp, 2)
        XCTAssertTrue(evaluation.newMilestones.isEmpty)
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
}
