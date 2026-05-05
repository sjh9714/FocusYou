import Foundation
import SwiftData
import Testing
@testable import Focus_You

@Suite("DataStoreRecoveryPreviewService")
@MainActor
struct DataStoreRecoveryPreviewServiceTests {
    @Test("backup preview fails clearly when no store file exists")
    func previewFailsWhenStoreFileIsMissing() throws {
        let backupDirectory = try makeTemporaryDirectory()
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: backupDirectory)
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        do {
            _ = try DataStoreRecoveryPreviewService.previewBackup(
                at: backupDirectory,
                temporaryDirectoryURL: temporaryDirectory
            )
            Issue.record("Expected preview to fail when the backup folder has no store file")
        } catch let error as DataStoreRecoveryPreviewError {
            #expect(error.errorDescription?.contains("백업 store 파일을 찾을 수 없습니다") == true)
        }

        #expect(try recoveryStagingDirectories(in: temporaryDirectory).isEmpty)
    }

    @Test("valid backup preview reads model counts and session range from a temporary copy")
    func validBackupPreviewReadsCountsAndSessionRange() throws {
        let backupDirectory = try makeTemporaryDirectory()
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: backupDirectory)
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let storeURL = backupDirectory.appendingPathComponent("default.store")
        let dates = try createPopulatedStore(at: storeURL)
        let originalStoreData = try Data(contentsOf: storeURL)
        let originalStoreModifiedAt = try modificationDate(of: storeURL)

        let preview = try DataStoreRecoveryPreviewService.previewBackup(
            at: backupDirectory,
            temporaryDirectoryURL: temporaryDirectory,
            now: fixedDate
        )

        #expect(preview.sourceStoreFileName == "default.store")
        #expect(preview.profileCount == 1)
        #expect(preview.blockedSiteCount == 1)
        #expect(preview.blockedAppCount == 1)
        #expect(preview.focusSessionCount == 2)
        #expect(preview.scheduleCount == 1)
        #expect(preview.badgeCount == 1)
        #expect(preview.sessionDateRange?.earliestStartedAt == dates.earliest)
        #expect(preview.sessionDateRange?.latestStartedAt == dates.latest)
        #expect(preview.recentSessions.map(\.startedAt) == [dates.latest, dates.earliest])
        #expect(preview.copiedStoreFiles.sorted() == [
            "default.store",
            "default.store-shm",
            "default.store-wal",
        ])

        #expect(try Data(contentsOf: storeURL) == originalStoreData)
        #expect(try modificationDate(of: storeURL) == originalStoreModifiedAt)
        #expect(try recoveryStagingDirectories(in: temporaryDirectory).isEmpty)
    }

    @Test("corrupt backup preview does not touch current support directory")
    func corruptBackupPreviewDoesNotTouchCurrentSupportDirectory() throws {
        let backupDirectory = try makeTemporaryDirectory()
        let temporaryDirectory = try makeTemporaryDirectory()
        let currentSupportDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: backupDirectory)
            try? FileManager.default.removeItem(at: temporaryDirectory)
            try? FileManager.default.removeItem(at: currentSupportDirectory)
        }

        try Data("not a swiftdata store".utf8).write(
            to: backupDirectory.appendingPathComponent("default.store")
        )
        let sentinelURL = currentSupportDirectory.appendingPathComponent("sentinel.txt")
        try Data("do-not-touch".utf8).write(to: sentinelURL)

        do {
            _ = try DataStoreRecoveryPreviewService.previewBackup(
                at: backupDirectory,
                temporaryDirectoryURL: temporaryDirectory
            )
            Issue.record("Expected preview to fail for a corrupt backup store")
        } catch let error as DataStoreRecoveryPreviewError {
            #expect(error.errorDescription?.contains("백업을 읽을 수 없습니다") == true)
        }

        #expect(try String(contentsOf: sentinelURL, encoding: .utf8) == "do-not-touch")
        #expect(try recoveryStagingDirectories(in: temporaryDirectory).isEmpty)
    }

    @Test("FocusYou.store backup is accepted when default.store is absent")
    func focusYouStoreBackupIsAccepted() throws {
        let backupDirectory = try makeTemporaryDirectory()
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: backupDirectory)
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        try createPopulatedStore(
            at: backupDirectory.appendingPathComponent("FocusYou.store")
        )

        let preview = try DataStoreRecoveryPreviewService.previewBackup(
            at: backupDirectory,
            temporaryDirectoryURL: temporaryDirectory
        )

        #expect(preview.sourceStoreFileName == "FocusYou.store")
        #expect(preview.profileCount == 1)
        #expect(preview.focusSessionCount == 2)
        #expect(try recoveryStagingDirectories(in: temporaryDirectory).isEmpty)
    }

    private var fixedDate: Date {
        Date(timeIntervalSince1970: 1_704_164_645)
    }

    @discardableResult
    private func createPopulatedStore(
        at storeURL: URL
    ) throws -> (earliest: Date, latest: Date) {
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

        let profile = BlockProfile(name: "Deep Work")
        let site = BlockedSite(domain: "example.com", category: "SNS")
        site.profile = profile
        let app = BlockedApp(bundleId: "com.example.app", name: "Example App")
        app.profile = profile
        let schedule = BlockSchedule(name: "Morning", startMinuteOfDay: 540, endMinuteOfDay: 600)
        schedule.profile = profile

        let earliest = Date(timeIntervalSince1970: 1_704_000_000)
        let latest = Date(timeIntervalSince1970: 1_704_010_000)
        let firstSession = FocusSession(timerMode: "free", plannedDuration: 600)
        firstSession.startedAt = earliest
        firstSession.endedAt = earliest.addingTimeInterval(300)
        firstSession.actualDuration = 300
        firstSession.wasCompleted = true
        firstSession.profileName = profile.name

        let secondSession = FocusSession(timerMode: "pomodoro", plannedDuration: 1_500)
        secondSession.startedAt = latest
        secondSession.endedAt = latest.addingTimeInterval(1_200)
        secondSession.actualDuration = 1_200
        secondSession.wasCompleted = false
        secondSession.profileName = profile.name

        let badge = Badge(
            milestoneID: "sessions_100",
            title: "100 Sessions",
            emoji: "100",
            desc: "Complete 100 sessions"
        )

        context.insert(profile)
        context.insert(site)
        context.insert(app)
        context.insert(schedule)
        context.insert(firstSession)
        context.insert(secondSession)
        context.insert(badge)
        try context.save()

        return (earliest, latest)
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
