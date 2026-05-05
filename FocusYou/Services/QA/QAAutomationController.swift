#if DEBUG
import Foundation
import SwiftData
import os

struct QAAutomationCommand: Decodable, Equatable {
    enum Action: String, Decodable {
        case startSession = "start_session"
        case stopSession = "stop_session"
        case resetToIdle = "reset_to_idle"
        case createDataBackup = "create_data_backup"
        case createDiagnosticsBundle = "create_diagnostics_bundle"
    }

    let id: String
    let action: Action
    let durationSeconds: TimeInterval?
    let domain: String?
    let destinationPath: String?
}

struct QAAutomationCommandResult: Encodable, Equatable {
    let id: String
    let status: String
    let message: String
    let handledAt: TimeInterval
    let outputPath: String?

    init(
        id: String,
        status: String,
        message: String,
        handledAt: TimeInterval,
        outputPath: String? = nil
    ) {
        self.id = id
        self.status = status
        self.message = message
        self.handledAt = handledAt
        self.outputPath = outputPath
    }
}

struct QAAutomationDataToolServices: @unchecked Sendable {
    let createBackup: (URL) throws -> URL
    let createDiagnosticsBundle: (URL) throws -> URL

    static let live = QAAutomationDataToolServices(
        createBackup: { destinationURL in
            try DataStoreBackupService.createBackup(
                destinationDirectoryURL: destinationURL
            ).backupDirectoryURL
        },
        createDiagnosticsBundle: { destinationURL in
            try SupportDiagnosticsBundleService.createBundle(
                destinationDirectoryURL: destinationURL
            ).bundleDirectoryURL
        }
    )

    static let noop = QAAutomationDataToolServices(
        createBackup: { _ in throw QAAutomationDataToolServiceError.unexpectedCall },
        createDiagnosticsBundle: { _ in throw QAAutomationDataToolServiceError.unexpectedCall }
    )
}

private enum QAAutomationDataToolServiceError: Error {
    case unexpectedCall
}

enum QAAutomationDataToolExecutor {
    static func execute(
        command: QAAutomationCommand,
        services: QAAutomationDataToolServices = .live,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) -> QAAutomationCommandResult? {
        switch command.action {
        case .createDataBackup:
            guard let destinationURL = destinationURL(
                from: command.destinationPath,
                fileManager: fileManager
            ) else {
                return invalidDestinationResult(command: command, now: now)
            }

            do {
                let outputURL = try services.createBackup(destinationURL)
                return QAAutomationCommandResult(
                    id: command.id,
                    status: "ok",
                    message: "created_data_backup",
                    handledAt: now.timeIntervalSince1970,
                    outputPath: outputURL.path
                )
            } catch {
                return QAAutomationCommandResult(
                    id: command.id,
                    status: "error",
                    message: "failed_to_create_data_backup",
                    handledAt: now.timeIntervalSince1970
                )
            }

        case .createDiagnosticsBundle:
            guard let destinationURL = destinationURL(
                from: command.destinationPath,
                fileManager: fileManager
            ) else {
                return invalidDestinationResult(command: command, now: now)
            }

            do {
                let outputURL = try services.createDiagnosticsBundle(destinationURL)
                return QAAutomationCommandResult(
                    id: command.id,
                    status: "ok",
                    message: "created_diagnostics_bundle",
                    handledAt: now.timeIntervalSince1970,
                    outputPath: outputURL.path
                )
            } catch {
                return QAAutomationCommandResult(
                    id: command.id,
                    status: "error",
                    message: "failed_to_create_diagnostics_bundle",
                    handledAt: now.timeIntervalSince1970
                )
            }

        case .startSession, .stopSession, .resetToIdle:
            return nil
        }
    }

    private static func invalidDestinationResult(
        command: QAAutomationCommand,
        now: Date
    ) -> QAAutomationCommandResult {
        QAAutomationCommandResult(
            id: command.id,
            status: "error",
            message: "invalid_destination",
            handledAt: now.timeIntervalSince1970
        )
    }

    private static func destinationURL(
        from destinationPath: String?,
        fileManager: FileManager
    ) -> URL? {
        guard let destinationPath else { return nil }
        let trimmedPath = destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }

        let url = URL(fileURLWithPath: trimmedPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            return nil
        }
        return url
    }
}

@MainActor
final class QAAutomationController {
    static let shared = QAAutomationController()

    private let defaults = UserDefaults.standard
    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "QAAutomation"
    )
    private let dataToolServices: QAAutomationDataToolServices

    private weak var appState: AppState?
    private var modelContext: ModelContext?
    private var pollTimer: Timer?
    private var isProcessingCommand = false

    private init(dataToolServices: QAAutomationDataToolServices = .live) {
        self.dataToolServices = dataToolServices
    }

    func startIfNeeded(appState: AppState, modelContext: ModelContext) {
        self.appState = appState
        self.modelContext = modelContext

        guard pollTimer == nil else { return }

        pollTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollCommand()
            }
        }

        logger.info("QA 자동화 브리지 시작")
    }

    private func pollCommand() async {
        guard defaults.bool(forKey: Constants.Settings.qaAutomationEnabledKey) else { return }
        guard !isProcessingCommand else { return }
        guard let appState, let modelContext else { return }

        guard let rawCommand = defaults.string(forKey: Constants.Settings.qaAutomationCommandKey),
              !rawCommand.isEmpty else {
            return
        }

        guard let commandData = rawCommand.data(using: .utf8),
              let command = try? JSONDecoder().decode(QAAutomationCommand.self, from: commandData) else {
            logger.error("QA 명령 파싱 실패")
            defaults.removeObject(forKey: Constants.Settings.qaAutomationCommandKey)
            publishResult(
                QAAutomationCommandResult(
                    id: "unknown",
                    status: "error",
                    message: "invalid_command_payload",
                    handledAt: Date().timeIntervalSince1970
                )
            )
            return
        }

        if defaults.string(forKey: Constants.Settings.qaAutomationHandledCommandIDKey) == command.id {
            return
        }

        isProcessingCommand = true
        defaults.set(command.id, forKey: Constants.Settings.qaAutomationHandledCommandIDKey)
        defaults.removeObject(forKey: Constants.Settings.qaAutomationCommandKey)

        let result = await execute(command: command, appState: appState, modelContext: modelContext)
        publishResult(result)

        isProcessingCommand = false
    }

    private func execute(
        command: QAAutomationCommand,
        appState: AppState,
        modelContext: ModelContext
    ) async -> QAAutomationCommandResult {
        if let dataToolResult = QAAutomationDataToolExecutor.execute(
            command: command,
            services: dataToolServices
        ) {
            return dataToolResult
        }

        switch command.action {
        case .startSession:
            if appState.focusState != .idle {
                return QAAutomationCommandResult(
                    id: command.id,
                    status: "error",
                    message: "session_already_running",
                    handledAt: Date().timeIntervalSince1970
                )
            }

            let minDuration = TimeInterval(Constants.Timer.minimumMinutes * 60)
            let maxDuration = TimeInterval(Constants.Timer.maximumMinutes * 60)
            let requestedDuration = command.durationSeconds ?? minDuration
            let duration = min(max(requestedDuration, minDuration), maxDuration)
            let domain = (command.domain ?? "example.com").normalizedDomain

            guard !domain.isEmpty else {
                return QAAutomationCommandResult(
                    id: command.id,
                    status: "error",
                    message: "invalid_domain",
                    handledAt: Date().timeIntervalSince1970
                )
            }

            let site = BlockedSite(domain: domain)
            await appState.startFocusSession(
                duration: duration,
                sites: [site],
                apps: [],
                modelContext: modelContext
            )

            guard appState.focusState == .focusing else {
                let failureMessage = appState.errorMessage ?? "failed_to_start"
                return QAAutomationCommandResult(
                    id: command.id,
                    status: "error",
                    message: failureMessage,
                    handledAt: Date().timeIntervalSince1970
                )
            }

            return QAAutomationCommandResult(
                id: command.id,
                status: "ok",
                message: "started:\(Int(duration))s:\(domain)",
                handledAt: Date().timeIntervalSince1970
            )

        case .stopSession:
            if appState.focusState == .idle {
                return QAAutomationCommandResult(
                    id: command.id,
                    status: "ok",
                    message: "already_idle",
                    handledAt: Date().timeIntervalSince1970
                )
            }

            await appState.stopSession(modelContext: modelContext)
            let status = appState.focusState == .idle ? "ok" : "error"
            let message = status == "ok"
                ? "stopped"
                : (appState.errorMessage ?? "failed_to_stop")

            return QAAutomationCommandResult(
                id: command.id,
                status: status,
                message: message,
                handledAt: Date().timeIntervalSince1970
            )

        case .resetToIdle:
            appState.resetToIdle()
            return QAAutomationCommandResult(
                id: command.id,
                status: "ok",
                message: "reset_to_idle",
                handledAt: Date().timeIntervalSince1970
            )

        case .createDataBackup, .createDiagnosticsBundle:
            return QAAutomationCommandResult(
                id: command.id,
                status: "error",
                message: "unsupported_data_tool_action",
                handledAt: Date().timeIntervalSince1970
            )
        }
    }

    private func publishResult(_ result: QAAutomationCommandResult) {
        guard let data = try? JSONEncoder().encode(result),
              let payload = String(data: data, encoding: .utf8) else {
            logger.error("QA 명령 결과 직렬화 실패")
            return
        }

        defaults.set(payload, forKey: Constants.Settings.qaAutomationResultKey)
        logger.info("QA 명령 처리 결과: \(result.status, privacy: .public)")
    }
}
#endif
