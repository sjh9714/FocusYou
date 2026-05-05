#if DEBUG
import Foundation
import Testing
@testable import Focus_You

@Suite("QAAutomationDataTool")
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

    private var fixedDate: Date {
        Date(timeIntervalSince1970: 1_714_867_200)
    }

    private enum StubError: Error {
        case unexpectedServiceCall
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
