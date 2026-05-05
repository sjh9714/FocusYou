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
                selectedCandidateIDs: [selected.id],
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
    }

    private func makeBackupStore() throws -> BackupFixture {
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
        session.startedAt = Date(timeIntervalSince1970: 1_704_010_000)
        session.complete(actualDuration: 600)
        let badge = Badge(
            milestoneID: "sessions_100",
            title: "100 Sessions",
            emoji: "100",
            desc: "Complete 100 sessions"
        )

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
        try context.save()

        return BackupFixture(
            directory: backupDirectory,
            temporaryDirectory: temporaryDirectory,
            storeURL: storeURL,
            importProfileCreatedAt: importProfileCreatedAt,
            itemCreatedAt: itemCreatedAt
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
}
