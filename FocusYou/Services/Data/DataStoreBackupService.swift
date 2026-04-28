import Foundation

struct DataStoreBackupResult: Equatable {
    let backupDirectoryURL: URL
    let manifestURL: URL
    let copiedFiles: [AppDataStoreFileReport]
}

private struct DataStoreBackupManifest: Encodable {
    let createdAt: Date
    let supportDirectoryPath: String
    let copiedFiles: [String]
    let diagnostics: AppDataStoreDiagnosticsReport
}

enum DataStoreBackupService {
    static func createBackup(
        destinationDirectoryURL: URL,
        diagnostics: AppDataStoreDiagnosticsReport = AppDataStoreDiagnostics.inspect(),
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws -> DataStoreBackupResult {
        let backupDirectoryURL = try nextBackupDirectoryURL(
            in: destinationDirectoryURL,
            fileManager: fileManager,
            now: now
        )
        try fileManager.createDirectory(
            at: backupDirectoryURL,
            withIntermediateDirectories: true
        )

        let copiedFiles = try diagnostics.copyableFiles.map { file in
            let destinationURL = backupDirectoryURL
                .appendingPathComponent(file.relativePath)
            let destinationParentURL = destinationURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: destinationParentURL,
                withIntermediateDirectories: true
            )
            try fileManager.copyItem(at: file.url, to: destinationURL)
            return file
        }

        let manifestURL = backupDirectoryURL.appendingPathComponent("diagnostics.json")
        let manifest = DataStoreBackupManifest(
            createdAt: now,
            supportDirectoryPath: diagnostics.supportDirectoryURL.path,
            copiedFiles: copiedFiles.map(\.relativePath),
            diagnostics: diagnostics
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: manifestURL, options: .atomic)

        return DataStoreBackupResult(
            backupDirectoryURL: backupDirectoryURL,
            manifestURL: manifestURL,
            copiedFiles: copiedFiles
        )
    }

    private static func nextBackupDirectoryURL(
        in destinationDirectoryURL: URL,
        fileManager: FileManager,
        now: Date
    ) throws -> URL {
        try fileManager.createDirectory(
            at: destinationDirectoryURL,
            withIntermediateDirectories: true
        )

        let baseName = "FocusYouBackup-\(filenameTimestamp(from: now))"
        var candidate = destinationDirectoryURL.appendingPathComponent(
            baseName,
            isDirectory: true
        )
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = destinationDirectoryURL.appendingPathComponent(
                "\(baseName)-\(suffix)",
                isDirectory: true
            )
            suffix += 1
        }
        return candidate
    }

    private static func filenameTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
