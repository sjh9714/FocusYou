import Foundation

struct AppDataStoreFileReport: Codable, Equatable, Identifiable {
    var id: String { relativePath }

    let relativePath: String
    let url: URL
    let exists: Bool
    let isRegularFile: Bool
    let isReadable: Bool
    let byteCount: Int64?
    let modifiedAt: Date?
}

struct AppDataStoreDiagnosticsReport: Codable, Equatable {
    let inspectedAt: Date
    let supportDirectoryURL: URL
    let supportDirectoryExists: Bool
    let files: [AppDataStoreFileReport]

    var copyableFiles: [AppDataStoreFileReport] {
        files.filter { $0.exists && $0.isRegularFile && $0.isReadable }
    }

    var isHealthy: Bool {
        files.allSatisfy { !$0.exists || ($0.isRegularFile && $0.isReadable) }
    }

    var statusSummary: String {
        guard supportDirectoryExists else {
            return String(localized: "Application Support 폴더가 아직 없습니다.")
        }

        let existingCount = files.filter(\.exists).count
        guard existingCount > 0 else {
            return String(localized: "백업할 데이터 파일이 아직 없습니다.")
        }

        let unreadableCount = files.filter { $0.exists && !$0.isReadable }.count
        if unreadableCount > 0 {
            return String(localized: "\(existingCount)개 파일 발견, \(unreadableCount)개 읽기 불가")
        }
        return String(localized: "\(existingCount)개 데이터 파일 확인됨")
    }

    var textSummary: String {
        var lines: [String] = [
            "Focus You Data Store Diagnostics",
            "Inspected At: \(Self.isoString(from: inspectedAt))",
            "Support Directory: \(supportDirectoryURL.path)",
            "Support Directory Exists: \(supportDirectoryExists ? "true" : "false")",
            "Status: \(statusSummary)",
            "",
            "Files:",
        ]

        for file in files {
            let size = file.byteCount.map(String.init) ?? "-"
            let modified = file.modifiedAt.map(Self.isoString(from:)) ?? "-"
            lines.append(
                "- \(file.relativePath): exists=\(file.exists), readable=\(file.isReadable), regular=\(file.isRegularFile), bytes=\(size), modified=\(modified)"
            )
        }

        return lines.joined(separator: "\n")
    }

    func file(named relativePath: String) -> AppDataStoreFileReport? {
        files.first { $0.relativePath == relativePath }
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

enum AppDataStoreDiagnostics {
    static func inspect(
        supportDirectoryURL: URL = AppModelContainerFactory.defaultSupportDirectoryURL,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) -> AppDataStoreDiagnosticsReport {
        var isDirectory: ObjCBool = false
        let directoryExists = fileManager.fileExists(
            atPath: supportDirectoryURL.path,
            isDirectory: &isDirectory
        ) && isDirectory.boolValue

        let relativePaths = candidateRelativePaths(
            supportDirectoryURL: supportDirectoryURL,
            fileManager: fileManager,
            directoryExists: directoryExists
        )

        let files = relativePaths.map { relativePath in
            fileReport(
                relativePath: relativePath,
                supportDirectoryURL: supportDirectoryURL,
                fileManager: fileManager
            )
        }

        return AppDataStoreDiagnosticsReport(
            inspectedAt: now,
            supportDirectoryURL: supportDirectoryURL,
            supportDirectoryExists: directoryExists,
            files: files
        )
    }

    private static let knownRelativePaths: Set<String> = [
        "default.store",
        "default.store-shm",
        "default.store-wal",
        "FocusYou.store",
        "FocusYou.store-shm",
        "FocusYou.store-wal",
        "hosts.backup",
        "blocking.active",
    ]

    private static func candidateRelativePaths(
        supportDirectoryURL: URL,
        fileManager: FileManager,
        directoryExists: Bool
    ) -> [String] {
        var paths = knownRelativePaths

        if directoryExists,
           let contents = try? fileManager.contentsOfDirectory(
               at: supportDirectoryURL,
               includingPropertiesForKeys: [.isRegularFileKey],
               options: [.skipsHiddenFiles]
           ) {
            for url in contents where isCandidateFileName(url.lastPathComponent) {
                paths.insert(url.lastPathComponent)
            }
        }

        return paths.sorted()
    }

    private static func isCandidateFileName(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        return knownRelativePaths.contains(name)
            || lowercased.hasSuffix(".store")
            || lowercased.hasSuffix(".store-shm")
            || lowercased.hasSuffix(".store-wal")
            || lowercased.hasSuffix(".sqlite")
            || lowercased.hasSuffix(".sqlite-shm")
            || lowercased.hasSuffix(".sqlite-wal")
    }

    private static func fileReport(
        relativePath: String,
        supportDirectoryURL: URL,
        fileManager: FileManager
    ) -> AppDataStoreFileReport {
        let url = supportDirectoryURL.appendingPathComponent(relativePath)
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        let isRegularFile = exists && !isDirectory.boolValue
        let isReadable = exists && isRegularFile && fileManager.isReadableFile(atPath: url.path)
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let byteCount = (attributes?[.size] as? NSNumber)?.int64Value
        let modifiedAt = attributes?[.modificationDate] as? Date

        return AppDataStoreFileReport(
            relativePath: relativePath,
            url: url,
            exists: exists,
            isRegularFile: isRegularFile,
            isReadable: isReadable,
            byteCount: byteCount,
            modifiedAt: modifiedAt
        )
    }
}
