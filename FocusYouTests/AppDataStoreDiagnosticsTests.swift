import Foundation
import Testing
@testable import Focus_You

@Suite("AppDataStoreDiagnostics")
struct AppDataStoreDiagnosticsTests {
    @Test("diagnostics reports existing, missing, and unreadable store files")
    func diagnosticsReportsFileStates() throws {
        let supportDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: supportDirectory) }

        let storeURL = supportDirectory.appendingPathComponent("default.store")
        try Data("store".utf8).write(to: storeURL)

        let unreadableURL = supportDirectory.appendingPathComponent("default.store-wal")
        try Data("wal".utf8).write(to: unreadableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0],
            ofItemAtPath: unreadableURL.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: unreadableURL.path
            )
        }

        let report = AppDataStoreDiagnostics.inspect(
            supportDirectoryURL: supportDirectory,
            now: fixedDate
        )

        let store = try #require(report.file(named: "default.store"))
        #expect(store.exists)
        #expect(store.isRegularFile)
        #expect(store.isReadable)
        #expect(store.byteCount == 5)

        let missing = try #require(report.file(named: "default.store-shm"))
        #expect(!missing.exists)
        #expect(!missing.isReadable)

        let unreadable = try #require(report.file(named: "default.store-wal"))
        #expect(unreadable.exists)
        #expect(!unreadable.isReadable)
    }

    @Test("backup copies discovered files and diagnostics without changing originals")
    func backupCopiesCopyableFilesAndManifestOnly() throws {
        let supportDirectory = try makeTemporaryDirectory()
        let destinationDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: supportDirectory)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }

        let storeURL = supportDirectory.appendingPathComponent("default.store")
        try Data("original".utf8).write(to: storeURL)

        let report = AppDataStoreDiagnostics.inspect(
            supportDirectoryURL: supportDirectory,
            now: fixedDate
        )

        let result = try DataStoreBackupService.createBackup(
            destinationDirectoryURL: destinationDirectory,
            diagnostics: report,
            now: fixedDate
        )

        #expect(result.backupDirectoryURL.lastPathComponent == "FocusYouBackup-20240102-030405")
        #expect(result.copiedFiles.map(\.relativePath) == ["default.store"])

        let copiedStoreURL = result.backupDirectoryURL.appendingPathComponent("default.store")
        #expect(FileManager.default.fileExists(atPath: copiedStoreURL.path))
        #expect(try String(contentsOf: copiedStoreURL, encoding: .utf8) == "original")
        #expect(try String(contentsOf: storeURL, encoding: .utf8) == "original")

        let manifestURL = result.backupDirectoryURL.appendingPathComponent("diagnostics.json")
        #expect(result.manifestURL == manifestURL)
        #expect(FileManager.default.fileExists(atPath: manifestURL.path))

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try #require(
            JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        )
        #expect(manifest["supportDirectoryPath"] as? String == supportDirectory.path)
    }

    @Test("backup destination collision uses suffix without overwriting existing backup")
    func backupDestinationCollisionUsesSuffix() throws {
        let supportDirectory = try makeTemporaryDirectory()
        let destinationDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: supportDirectory)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }

        try Data("store".utf8).write(
            to: supportDirectory.appendingPathComponent("default.store")
        )
        let existingBackup = destinationDirectory
            .appendingPathComponent("FocusYouBackup-20240102-030405")
        try FileManager.default.createDirectory(
            at: existingBackup,
            withIntermediateDirectories: true
        )
        try Data("keep".utf8).write(to: existingBackup.appendingPathComponent("keep.txt"))

        let report = AppDataStoreDiagnostics.inspect(
            supportDirectoryURL: supportDirectory,
            now: fixedDate
        )

        let result = try DataStoreBackupService.createBackup(
            destinationDirectoryURL: destinationDirectory,
            diagnostics: report,
            now: fixedDate
        )

        #expect(result.backupDirectoryURL.lastPathComponent == "FocusYouBackup-20240102-030405-2")
        #expect(FileManager.default.fileExists(atPath: existingBackup.appendingPathComponent("keep.txt").path))
    }

    private var fixedDate: Date {
        Date(timeIntervalSince1970: 1_704_164_645)
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
