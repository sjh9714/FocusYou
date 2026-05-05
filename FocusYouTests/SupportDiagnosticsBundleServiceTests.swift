import Foundation
import Testing
@testable import Focus_You

@Suite("SupportDiagnosticsBundleService")
struct SupportDiagnosticsBundleServiceTests {
    @Test("redactor removes sensitive local details while preserving status text")
    func redactorRemovesSensitiveDetails() {
        let redactor = DiagnosticsRedactor(
            homeDirectoryURL: URL(fileURLWithPath: "/Users/sungjh"),
            sensitiveTerms: ["Deep Work", "Slack"]
        )

        let output = redactor.redact(
            """
            Status: clean state
            Path: /Users/sungjh/Library/Application Support/FocusYou/default.store
            Email: support@example.com
            URL: https://youtube.com/watch?v=123
            Domain: news.ycombinator.com
            Profile: Deep Work
            App: Slack
            """
        )

        #expect(output.contains("Status: clean state"))
        #expect(!output.contains("/Users/sungjh"))
        #expect(!output.contains("support@example.com"))
        #expect(!output.contains("youtube.com"))
        #expect(!output.contains("news.ycombinator.com"))
        #expect(!output.contains("Deep Work"))
        #expect(!output.contains("Slack"))
        #expect(output.contains("<redacted>"))
    }

    @Test("bundle contains redacted manifest and does not mutate source files")
    func bundleContainsRedactedManifestWithoutMutatingSources() throws {
        let supportDirectory = try makeTemporaryDirectory()
        let destinationDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: supportDirectory)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }

        let storeURL = supportDirectory.appendingPathComponent("default.store")
        try Data("original-store".utf8).write(to: storeURL)
        let diagnostics = AppDataStoreDiagnostics.inspect(
            supportDirectoryURL: supportDirectory,
            now: fixedDate
        )

        let result = try SupportDiagnosticsBundleService.createBundle(
            destinationDirectoryURL: destinationDirectory,
            dataStoreDiagnostics: diagnostics,
            blockingSummary: SupportDiagnosticsBlockingSummary(
                hostsBlockingActive: true,
                privateRelayStatus: "disabled",
                activeIndicatorExists: true,
                hostsBackupExists: false,
                launchAgentExists: false,
                helperExists: true
            ),
            logCollector: FakeLogCollector(
                entries: [
                    UnifiedLogEntry(
                        date: fixedDate.addingTimeInterval(-60),
                        level: "info",
                        subsystem: Constants.App.subsystem,
                        category: "BlockingCoordinator",
                        message: "Blocked youtube.com for Deep Work at /Users/sungjh"
                    )
                ]
            ),
            now: fixedDate,
            homeDirectoryURL: URL(fileURLWithPath: "/Users/sungjh"),
            redactionCandidates: ["Deep Work", "youtube.com"]
        )

        #expect(result.bundleDirectoryURL.lastPathComponent == "FocusYouDiagnostics-20240102-030405")
        #expect(result.generatedFiles.sorted() == ["manifest.json", "redaction-policy.txt"])
        #expect(try String(contentsOf: storeURL, encoding: .utf8) == "original-store")

        let manifestText = try String(contentsOf: result.manifestURL, encoding: .utf8)
        #expect(manifestText.contains("\"status\" : \"collected\""))
        #expect(manifestText.contains("\"existingFileCount\" : 1"))
        #expect(manifestText.contains("\"hostsBlockingActive\" : true"))
        #expect(!manifestText.contains("youtube.com"))
        #expect(!manifestText.contains("Deep Work"))
        #expect(!manifestText.contains("/Users/sungjh"))
    }

    @Test("log collection failure is recorded without failing bundle creation")
    func logCollectionFailureIsRecordedWithoutFailingBundleCreation() throws {
        let supportDirectory = try makeTemporaryDirectory()
        let destinationDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: supportDirectory)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }

        let diagnostics = AppDataStoreDiagnostics.inspect(
            supportDirectoryURL: supportDirectory,
            now: fixedDate
        )

        let result = try SupportDiagnosticsBundleService.createBundle(
            destinationDirectoryURL: destinationDirectory,
            dataStoreDiagnostics: diagnostics,
            blockingSummary: .empty,
            logCollector: FailingLogCollector(),
            now: fixedDate,
            homeDirectoryURL: URL(fileURLWithPath: "/Users/sungjh")
        )

        let manifestText = try String(contentsOf: result.manifestURL, encoding: .utf8)
        #expect(manifestText.contains("\"status\" : \"failed\""))
        #expect(manifestText.contains("log collection failed"))
        #expect(!manifestText.contains("/Users/sungjh"))
    }

    @Test("bundle destination collision uses suffix without overwriting existing bundle")
    func bundleDestinationCollisionUsesSuffix() throws {
        let supportDirectory = try makeTemporaryDirectory()
        let destinationDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: supportDirectory)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }

        let existingBundle = destinationDirectory
            .appendingPathComponent("FocusYouDiagnostics-20240102-030405")
        try FileManager.default.createDirectory(
            at: existingBundle,
            withIntermediateDirectories: true
        )
        try Data("keep".utf8).write(to: existingBundle.appendingPathComponent("keep.txt"))

        let result = try SupportDiagnosticsBundleService.createBundle(
            destinationDirectoryURL: destinationDirectory,
            dataStoreDiagnostics: AppDataStoreDiagnostics.inspect(
                supportDirectoryURL: supportDirectory,
                now: fixedDate
            ),
            blockingSummary: .empty,
            logCollector: FakeLogCollector(entries: []),
            now: fixedDate
        )

        #expect(result.bundleDirectoryURL.lastPathComponent == "FocusYouDiagnostics-20240102-030405-2")
        #expect(FileManager.default.fileExists(atPath: existingBundle.appendingPathComponent("keep.txt").path))
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

private struct FakeLogCollector: UnifiedLogCollecting {
    let entries: [UnifiedLogEntry]

    func collectRecentEntries(since: Date, limit: Int) throws -> [UnifiedLogEntry] {
        Array(entries.sorted { $0.date < $1.date }.suffix(limit))
    }
}

private struct FailingLogCollector: UnifiedLogCollecting {
    func collectRecentEntries(since: Date, limit: Int) throws -> [UnifiedLogEntry] {
        throw Failure()
    }

    private struct Failure: LocalizedError {
        var errorDescription: String? {
            "log collection failed for /Users/sungjh"
        }
    }
}
