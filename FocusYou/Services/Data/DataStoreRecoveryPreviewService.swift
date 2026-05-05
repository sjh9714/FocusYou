import Foundation
import SwiftData

struct DataStoreRecoverySessionDateRange: Equatable {
    let earliestStartedAt: Date
    let latestStartedAt: Date
}

struct DataStoreRecoverySessionPreview: Equatable {
    let startedAt: Date
    let endedAt: Date?
    let timerMode: String
    let sessionType: String
    let actualDuration: Int
    let wasCompleted: Bool
}

struct DataStoreRecoveryPreview: Equatable {
    let inspectedAt: Date
    let sourceDirectoryURL: URL
    let sourceStoreFileName: String
    let copiedStoreFiles: [String]
    let profileCount: Int
    let blockedSiteCount: Int
    let blockedAppCount: Int
    let focusSessionCount: Int
    let scheduleCount: Int
    let badgeCount: Int
    let sessionDateRange: DataStoreRecoverySessionDateRange?
    let recentSessions: [DataStoreRecoverySessionPreview]

    var statusSummary: String {
        var summary = String(
            localized: "백업 미리보기: 프로필 \(profileCount)개, 사이트 \(blockedSiteCount)개, 앱 \(blockedAppCount)개, 세션 \(focusSessionCount)개, 스케줄 \(scheduleCount)개, 배지 \(badgeCount)개"
        )

        if let sessionDateRange {
            summary += String(
                localized: " · 세션 범위 \(Self.dateString(from: sessionDateRange.earliestStartedAt)) - \(Self.dateString(from: sessionDateRange.latestStartedAt))"
            )
        }

        return summary
    }

    private static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

enum DataStoreRecoveryPreviewError: Error, Equatable, LocalizedError {
    case backupDirectoryNotFound(URL)
    case storeFileNotFound(URL)
    case unreadableStoreFile(URL)
    case failedToCopyStore(String)
    case failedToReadBackup(String)

    var errorDescription: String? {
        switch self {
        case .backupDirectoryNotFound:
            return String(localized: "백업 폴더를 찾을 수 없습니다.")
        case .storeFileNotFound:
            return String(localized: "백업 store 파일을 찾을 수 없습니다.")
        case .unreadableStoreFile:
            return String(localized: "백업 store 파일을 읽을 수 없습니다.")
        case .failedToCopyStore(let reason):
            return String(localized: "백업을 임시 위치로 복사할 수 없습니다: \(reason)")
        case .failedToReadBackup(let reason):
            return String(localized: "백업을 읽을 수 없습니다: \(reason)")
        }
    }
}

@MainActor
struct DataStoreRecoveryCopiedStore {
    let context: ModelContext
    let sourceDirectoryURL: URL
    let sourceStoreFileName: String
    let copiedStoreFiles: [String]
}

@MainActor
enum DataStoreRecoveryStoreReader {
    private static let primaryStoreFileNames = [
        "default.store",
        "FocusYou.store",
    ]
    private static let stagingDirectoryPrefix = "FocusYouRecoveryPreview-"
    private static let deferredCleanupDirectoryPrefix = "FocusYouRecoveryDeferredCleanup-"
    private static let deferredCleanupGraceInterval: TimeInterval = 3_600

    static func withCopiedStore<Result>(
        at backupDirectoryURL: URL,
        temporaryDirectoryURL: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default,
        body: (DataStoreRecoveryCopiedStore) throws -> Result
    ) throws -> Result {
        purgeDeferredCleanupDirectories(fileManager: fileManager)
        try validateDirectory(backupDirectoryURL, fileManager: fileManager)

        let sourceStoreURL = try sourceStoreFileURL(
            in: backupDirectoryURL,
            fileManager: fileManager
        )
        let sourceStoreFiles = try readableStoreFileURLs(
            for: sourceStoreURL,
            fileManager: fileManager
        )

        let stagingDirectoryURL = temporaryDirectoryURL
            .appendingPathComponent("\(stagingDirectoryPrefix)\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(
                at: stagingDirectoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw DataStoreRecoveryPreviewError.failedToCopyStore(error.localizedDescription)
        }

        do {
            for fileURL in sourceStoreFiles {
                let destinationURL = stagingDirectoryURL
                    .appendingPathComponent(fileURL.lastPathComponent)
                try fileManager.copyItem(at: fileURL, to: destinationURL)
            }
        } catch {
            try? fileManager.removeItem(at: stagingDirectoryURL)
            throw DataStoreRecoveryPreviewError.failedToCopyStore(error.localizedDescription)
        }

        let stagedStoreURL = stagingDirectoryURL
            .appendingPathComponent(sourceStoreURL.lastPathComponent)
        do {
            let result = try readCopiedStore(
                at: stagedStoreURL,
                sourceDirectoryURL: backupDirectoryURL,
                sourceStoreFileName: sourceStoreURL.lastPathComponent,
                copiedStoreFiles: sourceStoreFiles.map(\.lastPathComponent),
                body: body
            )
            deferStagingDirectoryCleanup(stagingDirectoryURL, fileManager: fileManager)
            return result
        } catch let error as DataStoreRecoveryPreviewError {
            deferStagingDirectoryCleanup(stagingDirectoryURL, fileManager: fileManager)
            throw error
        } catch {
            deferStagingDirectoryCleanup(stagingDirectoryURL, fileManager: fileManager)
            throw DataStoreRecoveryPreviewError.failedToReadBackup(error.localizedDescription)
        }
    }

    private static func validateDirectory(
        _ directoryURL: URL,
        fileManager: FileManager
    ) throws {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: directoryURL.path,
            isDirectory: &isDirectory
        )

        guard exists, isDirectory.boolValue else {
            throw DataStoreRecoveryPreviewError.backupDirectoryNotFound(directoryURL)
        }
    }

    private static func sourceStoreFileURL(
        in backupDirectoryURL: URL,
        fileManager: FileManager
    ) throws -> URL {
        for fileName in primaryStoreFileNames {
            let candidate = backupDirectoryURL.appendingPathComponent(fileName)
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(
                atPath: candidate.path,
                isDirectory: &isDirectory
            )
            guard exists else { continue }

            guard !isDirectory.boolValue else {
                throw DataStoreRecoveryPreviewError.unreadableStoreFile(candidate)
            }
            guard fileManager.isReadableFile(atPath: candidate.path) else {
                throw DataStoreRecoveryPreviewError.unreadableStoreFile(candidate)
            }
            return candidate
        }

        throw DataStoreRecoveryPreviewError.storeFileNotFound(backupDirectoryURL)
    }

    private static func readableStoreFileURLs(
        for sourceStoreURL: URL,
        fileManager: FileManager
    ) throws -> [URL] {
        let sidecarSuffixes = ["", "-shm", "-wal"]
        return try sidecarSuffixes.compactMap { suffix in
            let fileURL = URL(fileURLWithPath: sourceStoreURL.path + suffix)
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(
                atPath: fileURL.path,
                isDirectory: &isDirectory
            )
            guard exists else { return nil }
            guard !isDirectory.boolValue,
                  fileManager.isReadableFile(atPath: fileURL.path) else {
                throw DataStoreRecoveryPreviewError.unreadableStoreFile(fileURL)
            }
            return fileURL
        }
    }

    private static func readCopiedStore<Result>(
        at stagedStoreURL: URL,
        sourceDirectoryURL: URL,
        sourceStoreFileName: String,
        copiedStoreFiles: [String],
        body: (DataStoreRecoveryCopiedStore) throws -> Result
    ) throws -> Result {
        try autoreleasepool {
            let container = try ModelContainer(
                for: BlockProfile.self,
                BlockedSite.self,
                BlockedApp.self,
                FocusSession.self,
                BlockSchedule.self,
                Badge.self,
                configurations: ModelConfiguration(url: stagedStoreURL)
            )
            let context = ModelContext(container)
            return try body(
                DataStoreRecoveryCopiedStore(
                    context: context,
                    sourceDirectoryURL: sourceDirectoryURL,
                    sourceStoreFileName: sourceStoreFileName,
                    copiedStoreFiles: copiedStoreFiles
                )
            )
        }
    }

    private static func deferStagingDirectoryCleanup(
        _ stagingDirectoryURL: URL,
        fileManager: FileManager
    ) {
        let deferredURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "\(deferredCleanupDirectoryPrefix)\(UUID().uuidString)",
                isDirectory: true
            )

        do {
            try fileManager.moveItem(at: stagingDirectoryURL, to: deferredURL)
        } catch {
            try? fileManager.removeItem(at: stagingDirectoryURL)
        }
    }

    private static func purgeDeferredCleanupDirectories(fileManager: FileManager) {
        let rootURL = FileManager.default.temporaryDirectory
        guard let candidates = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return
        }

        let cutoff = Date().addingTimeInterval(-deferredCleanupGraceInterval)
        for candidate in candidates
            where candidate.lastPathComponent.hasPrefix(deferredCleanupDirectoryPrefix) {
            let modifiedAt = (
                try? candidate.resourceValues(forKeys: [.contentModificationDateKey])
            )?.contentModificationDate ?? .distantPast

            guard modifiedAt < cutoff else { continue }
            try? fileManager.removeItem(at: candidate)
        }
    }
}

@MainActor
enum DataStoreRecoveryPreviewService {
    static func previewBackup(
        at backupDirectoryURL: URL,
        temporaryDirectoryURL: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws -> DataStoreRecoveryPreview {
        try DataStoreRecoveryStoreReader.withCopiedStore(
            at: backupDirectoryURL,
            temporaryDirectoryURL: temporaryDirectoryURL,
            fileManager: fileManager
        ) { copiedStore in
            try previewCopiedStore(copiedStore, now: now)
        }
    }

    private static func previewCopiedStore(
        _ copiedStore: DataStoreRecoveryCopiedStore,
        now: Date
    ) throws -> DataStoreRecoveryPreview {
        let context = copiedStore.context

        let sessions = try context.fetch(
            FetchDescriptor<FocusSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )
        let startedDates = sessions.map(\.startedAt)

        return DataStoreRecoveryPreview(
            inspectedAt: now,
            sourceDirectoryURL: copiedStore.sourceDirectoryURL,
            sourceStoreFileName: copiedStore.sourceStoreFileName,
            copiedStoreFiles: copiedStore.copiedStoreFiles,
            profileCount: try context.fetch(FetchDescriptor<BlockProfile>()).count,
            blockedSiteCount: try context.fetch(FetchDescriptor<BlockedSite>()).count,
            blockedAppCount: try context.fetch(FetchDescriptor<BlockedApp>()).count,
            focusSessionCount: sessions.count,
            scheduleCount: try context.fetch(FetchDescriptor<BlockSchedule>()).count,
            badgeCount: try context.fetch(FetchDescriptor<Badge>()).count,
            sessionDateRange: sessionDateRange(from: startedDates),
            recentSessions: sessions.prefix(5).map { session in
                DataStoreRecoverySessionPreview(
                    startedAt: session.startedAt,
                    endedAt: session.endedAt,
                    timerMode: session.timerMode,
                    sessionType: session.sessionType,
                    actualDuration: session.actualDuration,
                    wasCompleted: session.wasCompleted
                )
            }
        )
    }

    private static func sessionDateRange(
        from dates: [Date]
    ) -> DataStoreRecoverySessionDateRange? {
        guard let earliest = dates.min(),
              let latest = dates.max() else {
            return nil
        }

        return DataStoreRecoverySessionDateRange(
            earliestStartedAt: earliest,
            latestStartedAt: latest
        )
    }
}
