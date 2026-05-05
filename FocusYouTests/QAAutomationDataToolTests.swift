#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import Focus_You

@Suite("QAAutomationDataTool")
@MainActor
struct QAAutomationDataToolTests {
    @Test("create_data_backup returns generated output path")
    func createDataBackupReturnsOutputPath() throws {
        let destination = try makeTemporaryDirectory()
            .appendingPathComponent("QA Destination", isDirectory: true)
        let output = destination
            .appendingPathComponent("FocusYouBackup-20260505-010203", isDirectory: true)
        var receivedDestination: URL?

        let services = QAAutomationDataToolServices(
            createBackup: { url in
                receivedDestination = url
                return output
            },
            createDiagnosticsBundle: { _ in
                throw StubError.unexpectedServiceCall
            }
        )
        let command = QAAutomationCommand(
            id: "backup-command",
            action: .createDataBackup,
            durationSeconds: nil,
            domain: nil,
            destinationPath: destination.path
        )

        let result = try #require(
            QAAutomationDataToolExecutor.execute(
                command: command,
                services: services,
                now: fixedDate
            )
        )

        #expect(receivedDestination == destination)
        #expect(result.id == "backup-command")
        #expect(result.status == "ok")
        #expect(result.message == "created_data_backup")
        #expect(result.outputPath == output.path)
        #expect(result.handledAt == fixedDate.timeIntervalSince1970)
    }

    @Test("create_diagnostics_bundle returns generated output path")
    func createDiagnosticsBundleReturnsOutputPath() throws {
        let destination = try makeTemporaryDirectory()
            .appendingPathComponent("QA Destination", isDirectory: true)
        let output = destination
            .appendingPathComponent("FocusYouDiagnostics-20260505-010203", isDirectory: true)
        var receivedDestination: URL?

        let services = QAAutomationDataToolServices(
            createBackup: { _ in
                throw StubError.unexpectedServiceCall
            },
            createDiagnosticsBundle: { url in
                receivedDestination = url
                return output
            }
        )
        let command = QAAutomationCommand(
            id: "diagnostics-command",
            action: .createDiagnosticsBundle,
            durationSeconds: nil,
            domain: nil,
            destinationPath: destination.path
        )

        let result = try #require(
            QAAutomationDataToolExecutor.execute(
                command: command,
                services: services,
                now: fixedDate
            )
        )

        #expect(receivedDestination == destination)
        #expect(result.id == "diagnostics-command")
        #expect(result.status == "ok")
        #expect(result.message == "created_diagnostics_bundle")
        #expect(result.outputPath == output.path)
    }

    @Test("missing or blank destination returns invalid destination")
    func missingOrBlankDestinationReturnsInvalidDestination() throws {
        let services = QAAutomationDataToolServices.noop

        for destinationPath in [nil, "", "   "] {
            let command = QAAutomationCommand(
                id: "invalid-command",
                action: .createDataBackup,
                durationSeconds: nil,
                domain: nil,
                destinationPath: destinationPath
            )

            let result = try #require(
                QAAutomationDataToolExecutor.execute(
                    command: command,
                    services: services,
                    now: fixedDate
                )
            )

            #expect(result.status == "error")
            #expect(result.message == "invalid_destination")
            #expect(result.outputPath == nil)
        }
    }

    @Test("file destination returns invalid destination without calling services")
    func fileDestinationReturnsInvalidDestination() throws {
        let fileURL = try makeTemporaryDirectory()
            .appendingPathComponent("not-a-directory.txt")
        try "not a directory".write(to: fileURL, atomically: true, encoding: .utf8)
        var didCallService = false
        let services = QAAutomationDataToolServices(
            createBackup: { _ in
                didCallService = true
                throw StubError.unexpectedServiceCall
            },
            createDiagnosticsBundle: { _ in
                didCallService = true
                throw StubError.unexpectedServiceCall
            }
        )
        let command = QAAutomationCommand(
            id: "file-destination",
            action: .createDiagnosticsBundle,
            durationSeconds: nil,
            domain: nil,
            destinationPath: fileURL.path
        )

        let result = try #require(
            QAAutomationDataToolExecutor.execute(
                command: command,
                services: services,
                now: fixedDate
            )
        )

        #expect(!didCallService)
        #expect(result.status == "error")
        #expect(result.message == "invalid_destination")
        #expect(result.outputPath == nil)
    }

    @Test("preview_data_import returns backup candidate details")
    func previewDataImportReturnsCandidateDetails() throws {
        let backup = try makeTemporaryDirectory()
            .appendingPathComponent("FocusYouBackup-20260505-010203", isDirectory: true)
        try FileManager.default.createDirectory(
            at: backup,
            withIntermediateDirectories: true
        )
        let preview = makeImportPreview(
            backupDirectory: backup,
            candidates: [
                makeImportCandidate(
                    id: "profile-1",
                    siteCount: 2,
                    appCount: 1,
                    scheduleCount: 3
                ),
            ],
            focusSessionCount: 4,
            badgeCount: 5
        )
        var receivedBackup: URL?
        let services = QAAutomationDataToolServices(
            previewDataImport: { url in
                receivedBackup = url
                return preview
            }
        )
        let command = QAAutomationCommand(
            id: "preview-import",
            action: .previewDataImport,
            durationSeconds: nil,
            domain: nil,
            destinationPath: nil,
            backupPath: backup.path
        )

        let result = try #require(
            QAAutomationDataToolExecutor.execute(
                command: command,
                services: services,
                now: fixedDate
            )
        )

        #expect(receivedBackup == backup)
        #expect(result.status == "ok")
        #expect(result.message == "previewed_data_import")
        #expect(result.outputPath == nil)
        #expect(result.details?["profileCandidateCount"] == 1)
        #expect(result.details?["siteCandidateCount"] == 2)
        #expect(result.details?["appCandidateCount"] == 1)
        #expect(result.details?["scheduleCandidateCount"] == 3)
        #expect(result.details?["focusSessionCandidateCount"] == 4)
        #expect(result.details?["badgeCandidateCount"] == 5)
    }

    @Test("validate_data_import defaults to all candidates and skips history")
    func validateDataImportDefaultsToAllCandidatesAndSkipsHistory() throws {
        let backup = try makeTemporaryDirectory()
            .appendingPathComponent("FocusYouBackup-20260505-010203", isDirectory: true)
        try FileManager.default.createDirectory(
            at: backup,
            withIntermediateDirectories: true
        )
        let preview = makeImportPreview(
            backupDirectory: backup,
            candidates: [
                makeImportCandidate(id: "profile-1"),
                makeImportCandidate(id: "orphan-legacy-blocks"),
            ],
            focusSessionCount: 2,
            badgeCount: 1
        )
        var receivedSelection: DataStoreRecoveryImportSelection?
        let services = QAAutomationDataToolServices(
            previewDataImport: { _ in preview },
            validateDataImport: { _, selection in
                receivedSelection = selection
                return DataStoreRecoveryImportResult(
                    importedProfileCount: 2,
                    importedSiteCount: 3,
                    importedAppCount: 4,
                    importedScheduleCount: 5,
                    importedFocusSessionCount: 0,
                    importedBadgeCount: 0,
                    skippedFocusSessionCount: 2,
                    skippedBadgeCount: 1
                )
            }
        )
        let command = QAAutomationCommand(
            id: "validate-import",
            action: .validateDataImport,
            durationSeconds: nil,
            domain: nil,
            destinationPath: nil,
            backupPath: backup.path
        )

        let result = try #require(
            QAAutomationDataToolExecutor.execute(
                command: command,
                services: services,
                now: fixedDate
            )
        )

        #expect(receivedSelection?.selectedCandidateIDs == ["profile-1", "orphan-legacy-blocks"])
        #expect(receivedSelection?.includeFocusSessions == false)
        #expect(receivedSelection?.includeBadges == false)
        #expect(result.status == "ok")
        #expect(result.message == "validated_data_import")
        #expect(result.details?["selectedCandidateCount"] == 2)
        #expect(result.details?["importedProfileCount"] == 2)
        #expect(result.details?["importedSiteCount"] == 3)
        #expect(result.details?["importedAppCount"] == 4)
        #expect(result.details?["importedScheduleCount"] == 5)
        #expect(result.details?["importedFocusSessionCount"] == 0)
        #expect(result.details?["importedBadgeCount"] == 0)
        #expect(result.details?["skippedFocusSessionCount"] == 2)
        #expect(result.details?["skippedBadgeCount"] == 1)
    }

    @Test("validate_data_import honors selected ids and history flags")
    func validateDataImportHonorsSelectedIDsAndHistoryFlags() throws {
        let backup = try makeTemporaryDirectory()
            .appendingPathComponent("FocusYouBackup-20260505-010203", isDirectory: true)
        try FileManager.default.createDirectory(
            at: backup,
            withIntermediateDirectories: true
        )
        let preview = makeImportPreview(
            backupDirectory: backup,
            candidates: [
                makeImportCandidate(id: "profile-1"),
                makeImportCandidate(id: "profile-2"),
            ],
            focusSessionCount: 2,
            badgeCount: 1
        )
        var receivedSelection: DataStoreRecoveryImportSelection?
        let services = QAAutomationDataToolServices(
            previewDataImport: { _ in preview },
            validateDataImport: { _, selection in
                receivedSelection = selection
                return DataStoreRecoveryImportResult(
                    importedProfileCount: 1,
                    importedSiteCount: 0,
                    importedAppCount: 0,
                    importedScheduleCount: 0,
                    importedFocusSessionCount: 2,
                    importedBadgeCount: 1,
                    skippedFocusSessionCount: 0,
                    skippedBadgeCount: 0
                )
            }
        )
        let command = QAAutomationCommand(
            id: "validate-import-history",
            action: .validateDataImport,
            durationSeconds: nil,
            domain: nil,
            destinationPath: nil,
            backupPath: backup.path,
            selectedCandidateIDs: ["profile-2"],
            includeFocusSessions: true,
            includeBadges: true
        )

        let result = try #require(
            QAAutomationDataToolExecutor.execute(
                command: command,
                services: services,
                now: fixedDate
            )
        )

        #expect(receivedSelection?.selectedCandidateIDs == ["profile-2"])
        #expect(receivedSelection?.includeFocusSessions == true)
        #expect(receivedSelection?.includeBadges == true)
        #expect(result.details?["selectedCandidateCount"] == 1)
        #expect(result.details?["importedFocusSessionCount"] == 2)
        #expect(result.details?["importedBadgeCount"] == 1)
    }

    @Test("preview_data_import rejects missing blank or file backup paths")
    func previewDataImportRejectsInvalidBackupPaths() throws {
        let fileURL = try makeTemporaryDirectory()
            .appendingPathComponent("not-a-backup.txt")
        try "not a backup".write(to: fileURL, atomically: true, encoding: .utf8)
        let services = QAAutomationDataToolServices.noop

        for backupPath in [nil, "", "   ", fileURL.path] {
            let command = QAAutomationCommand(
                id: "invalid-backup",
                action: .previewDataImport,
                durationSeconds: nil,
                domain: nil,
                destinationPath: nil,
                backupPath: backupPath
            )

            let result = try #require(
                QAAutomationDataToolExecutor.execute(
                    command: command,
                    services: services,
                    now: fixedDate
                )
            )

            #expect(result.status == "error")
            #expect(result.message == "invalid_backup")
            #expect(result.details == nil)
        }
    }

    @Test("validate_data_import live service uses dry-run context")
    func validateDataImportLiveServiceUsesDryRunContext() throws {
        let backup = try makeBackupStore()
        defer {
            try? FileManager.default.removeItem(at: backup)
        }
        let currentContainer = try makeInMemoryContainer()
        let currentContext = ModelContext(currentContainer)
        #expect(try currentContext.fetch(FetchDescriptor<BlockProfile>()).isEmpty)

        let command = QAAutomationCommand(
            id: "live-validate-import",
            action: .validateDataImport,
            durationSeconds: nil,
            domain: nil,
            destinationPath: nil,
            backupPath: backup.path,
            includeFocusSessions: true,
            includeBadges: true
        )

        let result = try #require(
            QAAutomationDataToolExecutor.execute(
                command: command,
                services: .live,
                now: fixedDate
            )
        )

        #expect(result.status == "ok")
        #expect(result.details?["importedProfileCount"] == 1)
        #expect(result.details?["importedFocusSessionCount"] == 1)
        #expect(result.details?["importedBadgeCount"] == 1)
        #expect(try currentContext.fetch(FetchDescriptor<BlockProfile>()).isEmpty)
        #expect(try currentContext.fetch(FetchDescriptor<FocusSession>()).isEmpty)
        #expect(try currentContext.fetch(FetchDescriptor<Badge>()).isEmpty)
    }

    private var fixedDate: Date {
        Date(timeIntervalSince1970: 1_714_867_200)
    }

    private enum StubError: Error {
        case unexpectedServiceCall
    }

    private func makeImportCandidate(
        id: String,
        siteCount: Int = 0,
        appCount: Int = 0,
        scheduleCount: Int = 0
    ) -> DataStoreRecoveryImportProfileCandidate {
        DataStoreRecoveryImportProfileCandidate(
            id: id,
            displayName: id,
            sourceName: id,
            isOrphanLegacyBlocks: false,
            siteCount: siteCount,
            appCount: appCount,
            scheduleCount: scheduleCount
        )
    }

    private func makeImportPreview(
        backupDirectory: URL,
        candidates: [DataStoreRecoveryImportProfileCandidate],
        focusSessionCount: Int,
        badgeCount: Int
    ) -> DataStoreRecoveryImportPreview {
        DataStoreRecoveryImportPreview(
            inspectedAt: fixedDate,
            sourceDirectoryURL: backupDirectory,
            sourceStoreFileName: "default.store",
            copiedStoreFiles: ["default.store"],
            profileCandidates: candidates,
            skippedFocusSessionCount: focusSessionCount,
            skippedBadgeCount: badgeCount
        )
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BlockProfile.self,
            BlockedSite.self,
            BlockedApp.self,
            FocusSession.self,
            BlockSchedule.self,
            Badge.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeBackupStore() throws -> URL {
        let backupDirectory = try makeTemporaryDirectory()
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

        let profile = BlockProfile(name: "Dry Run")
        let site = BlockedSite(domain: "example.com")
        site.profile = profile

        let session = FocusSession(timerMode: "free", plannedDuration: 600)
        session.startedAt = Date(timeIntervalSince1970: 1_704_000_000)
        session.endedAt = Date(timeIntervalSince1970: 1_704_000_600)
        session.actualDuration = 600
        session.wasCompleted = true

        let badge = Badge(
            milestoneID: "sessions_100",
            title: "100 Sessions",
            emoji: "100",
            desc: "Complete 100 sessions"
        )
        badge.achievedAt = Date(timeIntervalSince1970: 1_704_000_700)

        context.insert(profile)
        context.insert(site)
        context.insert(session)
        context.insert(badge)
        try context.save()

        return backupDirectory
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
}
#endif
