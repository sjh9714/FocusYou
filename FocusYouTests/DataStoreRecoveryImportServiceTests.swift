import Foundation
import SwiftData
import Testing
@testable import Focus_You

@Suite("DataStoreRecoveryImportService")
@MainActor
struct DataStoreRecoveryImportServiceTests {
    @Test("missing store import fails without inserting into current context")
    func missingStoreImportFailsWithoutMutatingCurrentContext() throws {
        let backupDirectory = try makeTemporaryDirectory()
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: backupDirectory)
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let target = try makeTargetContext()
        target.context.insert(BlockProfile(name: "Existing"))
        try target.context.save()

        do {
            _ = try DataStoreRecoveryImportService.importSelectedCandidates(
                from: backupDirectory,
                selectedCandidateIDs: ["missing"],
                into: target.context,
                temporaryDirectoryURL: temporaryDirectory
            )
            Issue.record("Expected import to fail when the backup folder has no store")
        } catch {
            #expect(error.localizedDescription.contains("백업 store 파일을 찾을 수 없습니다"))
        }

        let profiles = try target.context.fetch(FetchDescriptor<BlockProfile>())
        #expect(profiles.map(\.name) == ["Existing"])
        #expect(try recoveryStagingDirectories(in: temporaryDirectory).isEmpty)
    }

    @Test("corrupt store import fails without inserting into current context")
    func corruptStoreImportFailsWithoutMutatingCurrentContext() throws {
        let backupDirectory = try makeTemporaryDirectory()
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: backupDirectory)
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        try Data("not a swiftdata store".utf8)
            .write(to: backupDirectory.appendingPathComponent("default.store"))

        let target = try makeTargetContext()

        do {
            _ = try DataStoreRecoveryImportService.importSelectedCandidates(
                from: backupDirectory,
                selectedCandidateIDs: ["corrupt"],
                into: target.context,
                temporaryDirectoryURL: temporaryDirectory
            )
            Issue.record("Expected import to fail for a corrupt backup")
        } catch {
            #expect(error.localizedDescription.contains("백업을 읽을 수 없습니다"))
        }

        #expect(try target.context.fetch(FetchDescriptor<BlockProfile>()).isEmpty)
        #expect(try recoveryStagingDirectories(in: temporaryDirectory).isEmpty)
    }

    @Test("stale selected candidate ids fail before mutating current context")
    func staleSelectedCandidateIDsFailWithoutMutatingCurrentContext() throws {
        let backup = try makeBackupStore()
        defer {
            try? FileManager.default.removeItem(at: backup.directory)
            try? FileManager.default.removeItem(at: backup.temporaryDirectory)
        }

        let target = try makeTargetContext()
        let preview = try DataStoreRecoveryImportService.previewImport(
            at: backup.directory,
            temporaryDirectoryURL: backup.temporaryDirectory
        )
        let selected = try #require(preview.profileCandidates.first { $0.sourceName == "Import Me" })

        do {
            _ = try DataStoreRecoveryImportService.importSelectedCandidates(
                from: backup.directory,
                selectedCandidateIDs: [selected.id, "stale-candidate-id"],
                into: target.context,
                temporaryDirectoryURL: backup.temporaryDirectory
            )
            Issue.record("Expected import to fail when any selected candidate id is stale")
        } catch {
            #expect(error.localizedDescription.contains("선택한 백업 항목을 찾을 수 없습니다"))
        }

        #expect(try target.context.fetch(FetchDescriptor<BlockProfile>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<BlockedSite>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<BlockedApp>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<BlockSchedule>()).isEmpty)
        #expect(try recoveryStagingDirectories(in: backup.temporaryDirectory).isEmpty)
    }

    @Test("empty selection fails before importing settings, sessions, or badges")
    func emptySelectionFailsBeforeImportingSettingsSessionsOrBadges() throws {
        let backup = try makeBackupStore()
        defer {
            try? FileManager.default.removeItem(at: backup.directory)
            try? FileManager.default.removeItem(at: backup.temporaryDirectory)
        }

        let target = try makeTargetContext()

        do {
            _ = try DataStoreRecoveryImportService.importSelectedCandidates(
                from: backup.directory,
                selection: DataStoreRecoveryImportSelection(
                    selectedCandidateIDs: [],
                    includeFocusSessions: true,
                    includeBadges: true
                ),
                into: target.context,
                temporaryDirectoryURL: backup.temporaryDirectory
            )
            Issue.record("Expected import to fail when no candidates are selected")
        } catch {
            #expect(error.localizedDescription.contains("가져올 백업 항목을 선택하세요"))
        }

        #expect(try target.context.fetch(FetchDescriptor<BlockProfile>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<BlockedSite>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<BlockedApp>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<BlockSchedule>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<FocusSession>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<Badge>()).isEmpty)
    }

    @Test("import preview summarizes candidates and skipped history")
    func importPreviewSummarizesCandidatesAndSkippedHistory() throws {
        let backup = try makeBackupStore()
        defer {
            try? FileManager.default.removeItem(at: backup.directory)
            try? FileManager.default.removeItem(at: backup.temporaryDirectory)
        }

        let preview = try DataStoreRecoveryImportService.previewImport(
            at: backup.directory,
            temporaryDirectoryURL: backup.temporaryDirectory,
            now: fixedDate
        )

        #expect(preview.sourceStoreFileName == "default.store")
        #expect(preview.skippedFocusSessionCount == 1)
        #expect(preview.skippedBadgeCount == 1)

        let importMe = try #require(preview.profileCandidates.first { $0.sourceName == "Import Me" })
        #expect(importMe.siteCount == 1)
        #expect(importMe.appCount == 1)
        #expect(importMe.scheduleCount == 1)
        #expect(!importMe.isOrphanLegacyBlocks)

        let orphan = try #require(preview.profileCandidates.first { $0.isOrphanLegacyBlocks })
        #expect(orphan.displayName == "Imported Legacy Blocks")
        #expect(orphan.siteCount == 1)
        #expect(orphan.appCount == 1)
        #expect(orphan.scheduleCount == 1)
        #expect(try recoveryStagingDirectories(in: backup.temporaryDirectory).isEmpty)
    }

    @Test("target-aware preview counts duplicate sessions and badges before import")
    func targetAwarePreviewCountsDuplicateSessionsAndBadgesBeforeImport() throws {
        let backup = try makeBackupStore(includeDuplicateBadge: true)
        defer {
            try? FileManager.default.removeItem(at: backup.directory)
            try? FileManager.default.removeItem(at: backup.temporaryDirectory)
        }

        let target = try makeTargetContext()
        let duplicateSession = FocusSession(timerMode: "free", plannedDuration: 600)
        duplicateSession.startedAt = backup.sessionStartedAt
        duplicateSession.endedAt = backup.sessionEndedAt
        duplicateSession.actualDuration = 600
        duplicateSession.overflowDuration = 30
        duplicateSession.sessionType = "focus"
        duplicateSession.wasCompleted = true
        target.context.insert(duplicateSession)

        let existingBadge = Badge(
            milestoneID: "streak_7",
            title: "7 Day Streak",
            emoji: "7",
            desc: "Existing badge"
        )
        existingBadge.achievedAt = Date(timeIntervalSince1970: 1_704_200_000)
        target.context.insert(existingBadge)
        try target.context.save()

        let preview = try DataStoreRecoveryImportService.previewImport(
            at: backup.directory,
            into: target.context,
            temporaryDirectoryURL: backup.temporaryDirectory,
            now: fixedDate
        )

        #expect(preview.skippedFocusSessionCount == 1)
        #expect(preview.duplicateFocusSessionCount == 1)
        #expect(preview.importableFocusSessionCount == 0)
        #expect(preview.skippedBadgeCount == 3)
        #expect(preview.duplicateBadgeCount == 2)
        #expect(preview.importableBadgeCount == 1)

        let selected = try #require(preview.profileCandidates.first { $0.sourceName == "Import Me" })
        let result = try DataStoreRecoveryImportService.importSelectedCandidates(
            from: backup.directory,
            selection: DataStoreRecoveryImportSelection(
                selectedCandidateIDs: [selected.id],
                includeFocusSessions: true,
                includeBadges: true
            ),
            into: target.context,
            temporaryDirectoryURL: backup.temporaryDirectory
        )

        #expect(result.importedFocusSessionCount == preview.importableFocusSessionCount)
        #expect(result.skippedFocusSessionCount == preview.duplicateFocusSessionCount)
        #expect(result.importedBadgeCount == preview.importableBadgeCount)
        #expect(result.skippedBadgeCount == preview.duplicateBadgeCount)
        #expect(try recoveryStagingDirectories(in: backup.temporaryDirectory).isEmpty)
    }

    @Test("selected profile import preserves settings, resolves name conflict, and skips history")
    func selectedProfileImportPreservesSettingsAndSkipsHistory() throws {
        let backup = try makeBackupStore()
        defer {
            try? FileManager.default.removeItem(at: backup.directory)
            try? FileManager.default.removeItem(at: backup.temporaryDirectory)
        }
        let originalStoreData = try Data(contentsOf: backup.storeURL)
        let originalStoreModifiedAt = try modificationDate(of: backup.storeURL)

        let target = try makeTargetContext()
        let existing = BlockProfile(name: "Import Me")
        existing.isDefault = true
        target.context.insert(existing)
        try target.context.save()

        let preview = try DataStoreRecoveryImportService.previewImport(
            at: backup.directory,
            temporaryDirectoryURL: backup.temporaryDirectory
        )
        let selected = try #require(preview.profileCandidates.first { $0.sourceName == "Import Me" })

        let result = try DataStoreRecoveryImportService.importSelectedCandidates(
            from: backup.directory,
            selectedCandidateIDs: [selected.id],
            into: target.context,
            temporaryDirectoryURL: backup.temporaryDirectory,
            now: fixedDate
        )

        #expect(result.importedProfileCount == 1)
        #expect(result.importedSiteCount == 1)
        #expect(result.importedAppCount == 1)
        #expect(result.importedScheduleCount == 1)
        #expect(result.importedFocusSessionCount == 0)
        #expect(result.importedBadgeCount == 0)
        #expect(result.skippedFocusSessionCount == 1)
        #expect(result.skippedBadgeCount == 1)

        let profiles = try target.context.fetch(
            FetchDescriptor<BlockProfile>(sortBy: [SortDescriptor(\.name)])
        )
        #expect(profiles.map(\.name) == ["Import Me", "Import Me (Imported)"])

        let imported = try #require(profiles.first { $0.name == "Import Me (Imported)" })
        #expect(!imported.isDefault)
        #expect(imported.icon == "sparkles")
        #expect(imported.color == "#123456")
        #expect(imported.timerMode == "pomodoro")
        #expect(imported.focusDuration == 1_800)
        #expect(imported.breakDuration == 420)
        #expect(imported.longBreakDuration == 1_200)
        #expect(imported.pomodoroCount == 6)
        #expect(imported.blocklistMode == "allowlist")
        #expect(imported.cancelIntensity == 2)
        #expect(imported.cancelLockoutMinutes == 15)
        #expect(imported.createdAt == backup.importProfileCreatedAt)

        let importedSite = try #require(imported.blockedSites.first)
        #expect(importedSite.domain == "deep-work")
        #expect(importedSite.category == "Focus")
        #expect(importedSite.isEnabled == false)
        #expect(importedSite.isKeywordPattern == true)
        #expect(importedSite.createdAt == backup.itemCreatedAt)

        let importedApp = try #require(imported.blockedApps.first)
        #expect(importedApp.bundleId == "com.example.deep")
        #expect(importedApp.name == "Deep App")
        #expect(importedApp.category == "Tools")
        #expect(importedApp.isEnabled == false)
        #expect(importedApp.createdAt == backup.itemCreatedAt)

        let importedSchedule = try #require(imported.schedules.first)
        #expect(importedSchedule.name == "Morning")
        #expect(importedSchedule.weekdays == "2,4,6")
        #expect(importedSchedule.startMinuteOfDay == 480)
        #expect(importedSchedule.endMinuteOfDay == 540)
        #expect(importedSchedule.isEnabled == false)
        #expect(importedSchedule.createdAt == backup.itemCreatedAt)

        #expect(try target.context.fetch(FetchDescriptor<FocusSession>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<Badge>()).isEmpty)
        #expect(try Data(contentsOf: backup.storeURL) == originalStoreData)
        #expect(try modificationDate(of: backup.storeURL) == originalStoreModifiedAt)
        #expect(try recoveryStagingDirectories(in: backup.temporaryDirectory).isEmpty)
    }

    @Test("focus session import preserves history fields and clears calendar event id")
    func focusSessionImportPreservesHistoryFieldsAndClearsCalendarEventID() throws {
        let backup = try makeBackupStore()
        defer {
            try? FileManager.default.removeItem(at: backup.directory)
            try? FileManager.default.removeItem(at: backup.temporaryDirectory)
        }

        let target = try makeTargetContext()
        let preview = try DataStoreRecoveryImportService.previewImport(
            at: backup.directory,
            temporaryDirectoryURL: backup.temporaryDirectory
        )
        let selected = try #require(preview.profileCandidates.first { $0.sourceName == "Import Me" })

        let result = try DataStoreRecoveryImportService.importSelectedCandidates(
            from: backup.directory,
            selection: DataStoreRecoveryImportSelection(
                selectedCandidateIDs: [selected.id],
                includeFocusSessions: true
            ),
            into: target.context,
            temporaryDirectoryURL: backup.temporaryDirectory
        )

        #expect(result.importedFocusSessionCount == 1)
        #expect(result.skippedFocusSessionCount == 0)
        #expect(result.importedBadgeCount == 0)
        #expect(result.skippedBadgeCount == 1)

        let sessions = try target.context.fetch(FetchDescriptor<FocusSession>())
        let imported = try #require(sessions.first)
        #expect(imported.timerMode == "free")
        #expect(imported.profileName == "Import Me")
        #expect(imported.startedAt == backup.sessionStartedAt)
        #expect(imported.endedAt == backup.sessionEndedAt)
        #expect(imported.plannedDuration == 600)
        #expect(imported.actualDuration == 600)
        #expect(imported.overflowDuration == 30)
        #expect(imported.sessionType == "focus")
        #expect(imported.wasCompleted)
        #expect(imported.intention == "Write recovery tests")
        #expect(imported.retrospectEmoji == "✅")
        #expect(imported.retrospectText == "Recovered cleanly")
        #expect(imported.retrospectRating == 5)
        #expect(imported.calendarEventID == nil)
        #expect(try target.context.fetch(FetchDescriptor<Badge>()).isEmpty)
    }

    @Test("duplicate focus sessions are skipped during history import")
    func duplicateFocusSessionsAreSkippedDuringHistoryImport() throws {
        let backup = try makeBackupStore()
        defer {
            try? FileManager.default.removeItem(at: backup.directory)
            try? FileManager.default.removeItem(at: backup.temporaryDirectory)
        }

        let target = try makeTargetContext()
        let duplicate = FocusSession(timerMode: "free", plannedDuration: 600)
        duplicate.startedAt = backup.sessionStartedAt
        duplicate.endedAt = backup.sessionEndedAt
        duplicate.actualDuration = 600
        duplicate.overflowDuration = 30
        duplicate.sessionType = "focus"
        duplicate.wasCompleted = true
        target.context.insert(duplicate)
        try target.context.save()

        let preview = try DataStoreRecoveryImportService.previewImport(
            at: backup.directory,
            temporaryDirectoryURL: backup.temporaryDirectory
        )
        let selected = try #require(preview.profileCandidates.first { $0.sourceName == "Import Me" })

        let result = try DataStoreRecoveryImportService.importSelectedCandidates(
            from: backup.directory,
            selection: DataStoreRecoveryImportSelection(
                selectedCandidateIDs: [selected.id],
                includeFocusSessions: true
            ),
            into: target.context,
            temporaryDirectoryURL: backup.temporaryDirectory
        )

        #expect(result.importedFocusSessionCount == 0)
        #expect(result.skippedFocusSessionCount == 1)
        #expect(try target.context.fetch(FetchDescriptor<FocusSession>()).count == 1)
    }

    @Test("badge import keeps existing badges and imports the earliest source badge")
    func badgeImportKeepsExistingBadgesAndImportsEarliestSourceBadge() throws {
        let backup = try makeBackupStore(includeDuplicateBadge: true)
        defer {
            try? FileManager.default.removeItem(at: backup.directory)
            try? FileManager.default.removeItem(at: backup.temporaryDirectory)
        }

        let target = try makeTargetContext()
        let existing = Badge(
            milestoneID: "streak_7",
            title: "7 Day Streak",
            emoji: "7",
            desc: "Existing badge"
        )
        existing.achievedAt = Date(timeIntervalSince1970: 1_704_200_000)
        target.context.insert(existing)
        try target.context.save()

        let preview = try DataStoreRecoveryImportService.previewImport(
            at: backup.directory,
            temporaryDirectoryURL: backup.temporaryDirectory
        )
        let selected = try #require(preview.profileCandidates.first { $0.sourceName == "Import Me" })

        let result = try DataStoreRecoveryImportService.importSelectedCandidates(
            from: backup.directory,
            selection: DataStoreRecoveryImportSelection(
                selectedCandidateIDs: [selected.id],
                includeBadges: true
            ),
            into: target.context,
            temporaryDirectoryURL: backup.temporaryDirectory
        )

        #expect(result.importedBadgeCount == 1)
        #expect(result.skippedBadgeCount == 2)
        #expect(result.importedFocusSessionCount == 0)
        #expect(result.skippedFocusSessionCount == 1)

        let badges = try target.context.fetch(
            FetchDescriptor<Badge>(sortBy: [SortDescriptor(\.milestoneID)])
        )
        #expect(badges.map(\.milestoneID) == ["sessions_100", "streak_7"])
        let imported = try #require(badges.first { $0.milestoneID == "sessions_100" })
        #expect(imported.title == "100 Sessions")
        #expect(imported.emoji == "100")
        #expect(imported.desc == "Complete 100 sessions")
        #expect(imported.achievedAt == backup.badgeAchievedAt)
    }

    @Test("save failure rolls back inserted recovery objects")
    func saveFailureRollsBackInsertedRecoveryObjects() throws {
        let backup = try makeBackupStore()
        defer {
            try? FileManager.default.removeItem(at: backup.directory)
            try? FileManager.default.removeItem(at: backup.temporaryDirectory)
        }

        let target = try makeTargetContext()
        let preview = try DataStoreRecoveryImportService.previewImport(
            at: backup.directory,
            temporaryDirectoryURL: backup.temporaryDirectory
        )
        let selected = try #require(preview.profileCandidates.first { $0.sourceName == "Import Me" })

        do {
            _ = try DataStoreRecoveryImportService.importSelectedCandidates(
                from: backup.directory,
                selection: DataStoreRecoveryImportSelection(
                    selectedCandidateIDs: [selected.id],
                    includeFocusSessions: true,
                    includeBadges: true
                ),
                into: target.context,
                temporaryDirectoryURL: backup.temporaryDirectory,
                save: { _ in throw SyntheticSaveError.failure }
            )
            Issue.record("Expected import to fail when saving the target context fails")
        } catch {
            #expect(error.localizedDescription.contains("가져온 데이터를 저장할 수 없습니다"))
        }

        #expect(try target.context.fetch(FetchDescriptor<BlockProfile>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<BlockedSite>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<BlockedApp>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<BlockSchedule>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<FocusSession>()).isEmpty)
        #expect(try target.context.fetch(FetchDescriptor<Badge>()).isEmpty)
    }

    @Test("orphan legacy blocks import as a dedicated profile")
    func orphanLegacyBlocksImportAsDedicatedProfile() throws {
        let backup = try makeBackupStore()
        defer {
            try? FileManager.default.removeItem(at: backup.directory)
            try? FileManager.default.removeItem(at: backup.temporaryDirectory)
        }

        let target = try makeTargetContext()
        let preview = try DataStoreRecoveryImportService.previewImport(
            at: backup.directory,
            temporaryDirectoryURL: backup.temporaryDirectory
        )
        let selected = try #require(preview.profileCandidates.first { $0.isOrphanLegacyBlocks })

        let result = try DataStoreRecoveryImportService.importSelectedCandidates(
            from: backup.directory,
            selectedCandidateIDs: [selected.id],
            into: target.context,
            temporaryDirectoryURL: backup.temporaryDirectory
        )

        #expect(result.importedProfileCount == 1)
        #expect(result.importedSiteCount == 1)
        #expect(result.importedAppCount == 1)
        #expect(result.importedScheduleCount == 1)

        let profiles = try target.context.fetch(FetchDescriptor<BlockProfile>())
        let imported = try #require(profiles.first)
        #expect(imported.name == "Imported Legacy Blocks")
        #expect(imported.blockedSites.map(\.domain) == ["legacy.example.com"])
        #expect(imported.blockedApps.map(\.bundleId) == ["com.example.legacy"])
        #expect(imported.schedules.map(\.name) == ["Legacy Schedule"])
    }

    @Test("backup recovery imports more profiles than free limit without using license gates")
    func backupRecoveryImportsMoreProfilesThanFreeLimit() throws {
        let backup = try makeBackupStore()
        defer {
            try? FileManager.default.removeItem(at: backup.directory)
            try? FileManager.default.removeItem(at: backup.temporaryDirectory)
        }

        let target = try makeTargetContext()
        let preview = try DataStoreRecoveryImportService.previewImport(
            at: backup.directory,
            temporaryDirectoryURL: backup.temporaryDirectory
        )
        let profileIDs = preview.profileCandidates
            .filter { !$0.isOrphanLegacyBlocks }
            .map(\.id)

        let result = try DataStoreRecoveryImportService.importSelectedCandidates(
            from: backup.directory,
            selectedCandidateIDs: Set(profileIDs),
            into: target.context,
            temporaryDirectoryURL: backup.temporaryDirectory
        )

        #expect(Constants.Subscription.freeProfileLimit == 1)
        #expect(result.importedProfileCount == 2)
        #expect(try target.context.fetch(FetchDescriptor<BlockProfile>()).count == 2)
    }

    private var fixedDate: Date {
        Date(timeIntervalSince1970: 1_704_164_645)
    }

    private enum SyntheticSaveError: Error {
        case failure
    }

    private func makeTargetContext() throws -> (container: ModelContainer, context: ModelContext) {
        let container = try ModelContainer(
            for: BlockProfile.self,
            BlockedSite.self,
            BlockedApp.self,
            FocusSession.self,
            BlockSchedule.self,
            Badge.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, ModelContext(container))
    }

    private struct BackupFixture {
        let directory: URL
        let temporaryDirectory: URL
        let storeURL: URL
        let importProfileCreatedAt: Date
        let itemCreatedAt: Date
        let sessionStartedAt: Date
        let sessionEndedAt: Date
        let badgeAchievedAt: Date
    }

    private func makeBackupStore(includeDuplicateBadge: Bool = false) throws -> BackupFixture {
        let backupDirectory = try makeTemporaryDirectory()
        let temporaryDirectory = try makeTemporaryDirectory()
        let storeURL = backupDirectory.appendingPathComponent("default.store")
        let container = try ModelContainer(
            for: BlockProfile.self,
            BlockedSite.self,
            BlockedApp.self,
            FocusSession.self,
            BlockSchedule.self,
            Badge.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        let context = ModelContext(container)

        let importProfileCreatedAt = Date(timeIntervalSince1970: 1_704_000_000)
        let itemCreatedAt = Date(timeIntervalSince1970: 1_704_000_120)

        let importProfile = BlockProfile(name: "Import Me", icon: "sparkles", color: "#123456")
        importProfile.isDefault = true
        importProfile.createdAt = importProfileCreatedAt
        importProfile.timerMode = "pomodoro"
        importProfile.focusDuration = 1_800
        importProfile.breakDuration = 420
        importProfile.longBreakDuration = 1_200
        importProfile.pomodoroCount = 6
        importProfile.blocklistMode = "allowlist"
        importProfile.cancelIntensity = 2
        importProfile.cancelLockoutMinutes = 15

        let site = BlockedSite(domain: "deep-work", category: "Focus", isKeywordPattern: true)
        site.isEnabled = false
        site.createdAt = itemCreatedAt
        site.profile = importProfile

        let app = BlockedApp(bundleId: "com.example.deep", name: "Deep App", category: "Tools")
        app.isEnabled = false
        app.createdAt = itemCreatedAt
        app.profile = importProfile

        let schedule = BlockSchedule(
            name: "Morning",
            weekdays: "2,4,6",
            startMinuteOfDay: 480,
            endMinuteOfDay: 540
        )
        schedule.isEnabled = false
        schedule.createdAt = itemCreatedAt
        schedule.profile = importProfile

        let skipProfile = BlockProfile(name: "Skip Me")
        let skipSite = BlockedSite(domain: "skip.example.com")
        skipSite.profile = skipProfile

        let orphanSite = BlockedSite(domain: "legacy.example.com", category: "Legacy")
        let orphanApp = BlockedApp(
            bundleId: "com.example.legacy",
            name: "Legacy App",
            category: "Legacy"
        )
        let orphanSchedule = BlockSchedule(
            name: "Legacy Schedule",
            weekdays: "3",
            startMinuteOfDay: 600,
            endMinuteOfDay: 660
        )

        let session = FocusSession(timerMode: "free", plannedDuration: 600)
        let sessionStartedAt = Date(timeIntervalSince1970: 1_704_010_000)
        let sessionEndedAt = Date(timeIntervalSince1970: 1_704_010_600)
        session.profileName = "Import Me"
        session.startedAt = sessionStartedAt
        session.endedAt = sessionEndedAt
        session.actualDuration = 600
        session.overflowDuration = 30
        session.sessionType = "focus"
        session.wasCompleted = true
        session.intention = "Write recovery tests"
        session.retrospectEmoji = "✅"
        session.retrospectText = "Recovered cleanly"
        session.retrospectRating = 5
        session.calendarEventID = "event-from-backup"
        let badge = Badge(
            milestoneID: "sessions_100",
            title: "100 Sessions",
            emoji: "100",
            desc: "Complete 100 sessions"
        )
        let badgeAchievedAt = Date(timeIntervalSince1970: 1_704_010_700)
        badge.achievedAt = badgeAchievedAt
        let duplicateBadge = Badge(
            milestoneID: "sessions_100",
            title: "100 Sessions Later",
            emoji: "100",
            desc: "Later duplicate"
        )
        duplicateBadge.achievedAt = Date(timeIntervalSince1970: 1_704_010_900)
        let existingSourceBadge = Badge(
            milestoneID: "streak_7",
            title: "7 Day Streak",
            emoji: "7",
            desc: "Already present in target"
        )
        existingSourceBadge.achievedAt = Date(timeIntervalSince1970: 1_704_010_800)

        context.insert(importProfile)
        context.insert(site)
        context.insert(app)
        context.insert(schedule)
        context.insert(skipProfile)
        context.insert(skipSite)
        context.insert(orphanSite)
        context.insert(orphanApp)
        context.insert(orphanSchedule)
        context.insert(session)
        context.insert(badge)
        if includeDuplicateBadge {
            context.insert(duplicateBadge)
            context.insert(existingSourceBadge)
        }
        try context.save()

        return BackupFixture(
            directory: backupDirectory,
            temporaryDirectory: temporaryDirectory,
            storeURL: storeURL,
            importProfileCreatedAt: importProfileCreatedAt,
            itemCreatedAt: itemCreatedAt,
            sessionStartedAt: sessionStartedAt,
            sessionEndedAt: sessionEndedAt,
            badgeAchievedAt: badgeAchievedAt
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    private func modificationDate(of url: URL) throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try #require(attributes[.modificationDate] as? Date)
    }

    private func recoveryStagingDirectories(in temporaryDirectory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasPrefix("FocusYouRecoveryPreview-") }
    }
}
