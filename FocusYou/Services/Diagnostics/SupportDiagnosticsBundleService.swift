import Foundation
import OSLog

struct DiagnosticsRedactor {
    private let homeDirectoryPath: String
    private let sensitiveTerms: [String]

    init(
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        sensitiveTerms: [String] = []
    ) {
        self.homeDirectoryPath = homeDirectoryURL.path
        self.sensitiveTerms = sensitiveTerms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
    }

    func redact(_ input: String) -> String {
        var output = input

        if !homeDirectoryPath.isEmpty {
            output = replacingMatches(
                in: output,
                pattern: NSRegularExpression.escapedPattern(for: homeDirectoryPath)
            )
        }

        for term in sensitiveTerms {
            output = replacingMatches(
                in: output,
                pattern: NSRegularExpression.escapedPattern(for: term),
                options: [.caseInsensitive]
            )
        }

        output = replacingMatches(
            in: output,
            pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            options: [.caseInsensitive]
        )
        output = replacingMatches(
            in: output,
            pattern: #"https?://[^\s<>"']+"#,
            options: [.caseInsensitive]
        )
        output = replacingMatches(
            in: output,
            pattern: #"\b(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}\b"#,
            options: [.caseInsensitive]
        )

        return output
    }

    private func replacingMatches(
        in input: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return input
        }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(
            in: input,
            options: [],
            range: range,
            withTemplate: "<redacted>"
        )
    }
}

struct UnifiedLogEntry: Codable, Equatable {
    let date: Date
    let level: String
    let subsystem: String
    let category: String
    let message: String
}

protocol UnifiedLogCollecting {
    func collectRecentEntries(since: Date, limit: Int) throws -> [UnifiedLogEntry]
}

struct OSLogStoreUnifiedLogCollector: UnifiedLogCollecting {
    func collectRecentEntries(since: Date, limit: Int) throws -> [UnifiedLogEntry] {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let position = store.position(date: since)
        let predicate = NSPredicate(
            format: "subsystem == %@",
            Constants.App.subsystem
        )
        let entries = try store.getEntries(at: position, matching: predicate)

        return Array(
            entries.compactMap { entry -> UnifiedLogEntry? in
                guard let log = entry as? OSLogEntryLog else { return nil }
                return UnifiedLogEntry(
                    date: log.date,
                    level: String(describing: log.level),
                    subsystem: log.subsystem,
                    category: log.category,
                    message: log.composedMessage
                )
            }
            .sorted { $0.date < $1.date }
            .suffix(max(limit, 0))
        )
    }
}

struct SupportDiagnosticsBlockingSummary: Codable, Equatable {
    let hostsBlockingActive: Bool?
    let privateRelayStatus: String?
    let activeIndicatorExists: Bool
    let hostsBackupExists: Bool
    let launchAgentExists: Bool
    let helperExists: Bool

    static let empty = SupportDiagnosticsBlockingSummary(
        hostsBlockingActive: nil,
        privateRelayStatus: nil,
        activeIndicatorExists: false,
        hostsBackupExists: false,
        launchAgentExists: false,
        helperExists: false
    )

    static func current(
        hostsBlockingActive: Bool? = nil,
        privateRelayStatus: PrivateRelayDetector.Status? = nil,
        fileManager: FileManager = .default
    ) -> SupportDiagnosticsBlockingSummary {
        SupportDiagnosticsBlockingSummary(
            hostsBlockingActive: hostsBlockingActive,
            privateRelayStatus: privateRelayStatus.map(statusDescription),
            activeIndicatorExists: fileManager.fileExists(atPath: Constants.Blocking.activeIndicatorPath),
            hostsBackupExists: fileManager.fileExists(atPath: Constants.Blocking.hostsBackupPath),
            launchAgentExists: fileManager.fileExists(atPath: Constants.App.launchAgentPath),
            helperExists: fileManager.fileExists(atPath: Constants.Blocking.helperPath)
        )
    }

    private static func statusDescription(_ status: PrivateRelayDetector.Status) -> String {
        switch status {
        case .enabled: return "enabled"
        case .disabled: return "disabled"
        case .unknown: return "unknown"
        }
    }
}

struct SupportDiagnosticsBundleResult: Equatable {
    let bundleDirectoryURL: URL
    let manifestURL: URL
    let generatedFiles: [String]
}

private struct SupportDiagnosticsManifest: Codable, Equatable {
    let createdAt: Date
    let app: SupportDiagnosticsAppInfo
    let system: SupportDiagnosticsSystemInfo
    let dataStore: SupportDiagnosticsDataStoreSummary
    let blocking: SupportDiagnosticsBlockingSummary
    let unifiedLogs: SupportDiagnosticsLogSummary
    let redactionPolicy: SupportDiagnosticsRedactionPolicy
}

private struct SupportDiagnosticsAppInfo: Codable, Equatable {
    let appName: String
    let bundleIdentifier: String
    let marketingVersion: String
    let buildNumber: String

    static func current(bundle: Bundle = .main) -> SupportDiagnosticsAppInfo {
        let info = bundle.infoDictionary ?? [:]
        return SupportDiagnosticsAppInfo(
            appName: (info["CFBundleDisplayName"] as? String)
                ?? (info["CFBundleName"] as? String)
                ?? "Focus You",
            bundleIdentifier: bundle.bundleIdentifier ?? Constants.App.bundleIdentifier,
            marketingVersion: (info["CFBundleShortVersionString"] as? String) ?? "unknown",
            buildNumber: (info["CFBundleVersion"] as? String) ?? "unknown"
        )
    }
}

private struct SupportDiagnosticsSystemInfo: Codable, Equatable {
    let osVersion: String
    let processName: String

    static func current(processInfo: ProcessInfo = .processInfo) -> SupportDiagnosticsSystemInfo {
        SupportDiagnosticsSystemInfo(
            osVersion: processInfo.operatingSystemVersionString,
            processName: processInfo.processName
        )
    }
}

private struct SupportDiagnosticsDataStoreSummary: Codable, Equatable {
    struct FileSummary: Codable, Equatable {
        let relativePath: String
        let exists: Bool
        let isReadable: Bool
        let byteCount: Int64?
    }

    let supportDirectoryExists: Bool
    let statusSummary: String
    let existingFileCount: Int
    let readableFileCount: Int
    let unreadableFileCount: Int
    let totalByteCount: Int64
    let files: [FileSummary]

    init(
        diagnostics: AppDataStoreDiagnosticsReport,
        redactor: DiagnosticsRedactor
    ) {
        let existingFiles = diagnostics.files.filter(\.exists)
        self.supportDirectoryExists = diagnostics.supportDirectoryExists
        self.statusSummary = redactor.redact(diagnostics.statusSummary)
        self.existingFileCount = existingFiles.count
        self.readableFileCount = existingFiles.filter(\.isReadable).count
        self.unreadableFileCount = existingFiles.filter { !$0.isReadable }.count
        self.totalByteCount = existingFiles.compactMap(\.byteCount).reduce(0, +)
        self.files = diagnostics.files.map { file in
            FileSummary(
                relativePath: redactor.redact(file.relativePath),
                exists: file.exists,
                isReadable: file.isReadable,
                byteCount: file.byteCount
            )
        }
    }
}

private struct SupportDiagnosticsLogSummary: Codable, Equatable {
    let status: String
    let since: Date
    let limit: Int
    let returnedCount: Int
    let errorDescription: String?
    let entries: [UnifiedLogEntry]

    static func collected(
        since: Date,
        limit: Int,
        entries: [UnifiedLogEntry]
    ) -> SupportDiagnosticsLogSummary {
        SupportDiagnosticsLogSummary(
            status: "collected",
            since: since,
            limit: limit,
            returnedCount: entries.count,
            errorDescription: nil,
            entries: entries
        )
    }

    static func failed(
        since: Date,
        limit: Int,
        errorDescription: String
    ) -> SupportDiagnosticsLogSummary {
        SupportDiagnosticsLogSummary(
            status: "failed",
            since: since,
            limit: limit,
            returnedCount: 0,
            errorDescription: errorDescription,
            entries: []
        )
    }
}

private struct SupportDiagnosticsRedactionPolicy: Codable, Equatable {
    let version: Int
    let mode: String
    let redactedValues: [String]

    static let current = SupportDiagnosticsRedactionPolicy(
        version: 1,
        mode: "local-only-sensitive-data-redacted",
        redactedValues: [
            "home directory paths",
            "email addresses",
            "URLs and domain-like strings",
            "caller-provided profile, app, and site names",
        ]
    )

    var textDescription: String {
        """
        Focus You diagnostics redaction policy
        Version: \(version)
        Mode: \(mode)
        Redacted values:
        - \(redactedValues.joined(separator: "\n- "))
        """
    }
}

enum SupportDiagnosticsBundleService {
    static func createBundle(
        destinationDirectoryURL: URL,
        dataStoreDiagnostics: AppDataStoreDiagnosticsReport = AppDataStoreDiagnostics.inspect(),
        blockingSummary: SupportDiagnosticsBlockingSummary = .current(),
        logCollector: UnifiedLogCollecting = OSLogStoreUnifiedLogCollector(),
        fileManager: FileManager = .default,
        now: Date = Date(),
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        redactionCandidates: [String] = [],
        logLookbackSeconds: TimeInterval = 3_600,
        maxLogEntries: Int = 200
    ) throws -> SupportDiagnosticsBundleResult {
        let bundleDirectoryURL = try nextBundleDirectoryURL(
            in: destinationDirectoryURL,
            fileManager: fileManager,
            now: now
        )
        try fileManager.createDirectory(
            at: bundleDirectoryURL,
            withIntermediateDirectories: true
        )

        let redactor = DiagnosticsRedactor(
            homeDirectoryURL: homeDirectoryURL,
            sensitiveTerms: redactionCandidates
        )
        let since = now.addingTimeInterval(-logLookbackSeconds)
        let logs = collectLogs(
            collector: logCollector,
            since: since,
            limit: maxLogEntries,
            redactor: redactor
        )
        let manifest = SupportDiagnosticsManifest(
            createdAt: now,
            app: .current(),
            system: .current(),
            dataStore: SupportDiagnosticsDataStoreSummary(
                diagnostics: dataStoreDiagnostics,
                redactor: redactor
            ),
            blocking: blockingSummary,
            unifiedLogs: logs,
            redactionPolicy: .current
        )

        let manifestURL = bundleDirectoryURL.appendingPathComponent("manifest.json")
        let policyURL = bundleDirectoryURL.appendingPathComponent("redaction-policy.txt")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        try SupportDiagnosticsRedactionPolicy.current.textDescription
            .write(to: policyURL, atomically: true, encoding: .utf8)

        return SupportDiagnosticsBundleResult(
            bundleDirectoryURL: bundleDirectoryURL,
            manifestURL: manifestURL,
            generatedFiles: [
                manifestURL.lastPathComponent,
                policyURL.lastPathComponent,
            ]
        )
    }

    private static func collectLogs(
        collector: UnifiedLogCollecting,
        since: Date,
        limit: Int,
        redactor: DiagnosticsRedactor
    ) -> SupportDiagnosticsLogSummary {
        do {
            let entries = try collector.collectRecentEntries(since: since, limit: limit)
                .sorted { $0.date < $1.date }
                .suffix(max(limit, 0))
                .map { entry in
                    UnifiedLogEntry(
                        date: entry.date,
                        level: entry.level,
                        subsystem: entry.subsystem,
                        category: entry.category,
                        message: redactor.redact(entry.message)
                    )
                }
            return .collected(since: since, limit: limit, entries: Array(entries))
        } catch {
            return .failed(
                since: since,
                limit: limit,
                errorDescription: redactor.redact(error.localizedDescription)
            )
        }
    }

    private static func nextBundleDirectoryURL(
        in destinationDirectoryURL: URL,
        fileManager: FileManager,
        now: Date
    ) throws -> URL {
        try fileManager.createDirectory(
            at: destinationDirectoryURL,
            withIntermediateDirectories: true
        )

        let baseName = "FocusYouDiagnostics-\(filenameTimestamp(from: now))"
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
