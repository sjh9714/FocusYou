#if DEBUG
import Foundation
import SwiftData
import os

@MainActor
final class QAAutomationController {
    static let shared = QAAutomationController()

    private struct Command: Decodable {
        enum Action: String, Decodable {
            case startSession = "start_session"
            case stopSession = "stop_session"
            case resetToIdle = "reset_to_idle"
        }

        let id: String
        let action: Action
        let durationSeconds: TimeInterval?
        let domain: String?
    }

    private struct CommandResult: Encodable {
        let id: String
        let status: String
        let message: String
        let handledAt: TimeInterval
    }

    private let defaults = UserDefaults.standard
    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "QAAutomation"
    )

    private weak var appState: AppState?
    private var modelContext: ModelContext?
    private var pollTimer: Timer?
    private var isProcessingCommand = false

    private init() {}

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
              let command = try? JSONDecoder().decode(Command.self, from: commandData) else {
            logger.error("QA 명령 파싱 실패")
            defaults.removeObject(forKey: Constants.Settings.qaAutomationCommandKey)
            publishResult(
                CommandResult(
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
        command: Command,
        appState: AppState,
        modelContext: ModelContext
    ) async -> CommandResult {
        switch command.action {
        case .startSession:
            if appState.focusState != .idle {
                return CommandResult(
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
                return CommandResult(
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
                return CommandResult(
                    id: command.id,
                    status: "error",
                    message: failureMessage,
                    handledAt: Date().timeIntervalSince1970
                )
            }

            return CommandResult(
                id: command.id,
                status: "ok",
                message: "started:\(Int(duration))s:\(domain)",
                handledAt: Date().timeIntervalSince1970
            )

        case .stopSession:
            if appState.focusState == .idle {
                return CommandResult(
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

            return CommandResult(
                id: command.id,
                status: status,
                message: message,
                handledAt: Date().timeIntervalSince1970
            )

        case .resetToIdle:
            appState.resetToIdle()
            return CommandResult(
                id: command.id,
                status: "ok",
                message: "reset_to_idle",
                handledAt: Date().timeIntervalSince1970
            )
        }
    }

    private func publishResult(_ result: CommandResult) {
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
