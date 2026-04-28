import AppIntents
import SwiftData

// MARK: - 집중 중지 인텐트

struct StopFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "집중 중지"
    static let description: IntentDescription = "현재 진행 중인 집중 세션을 중지합니다."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let appState = AppState.shared else {
            throw IntentError.appNotRunning
        }

        guard appState.focusState == .focusing || appState.focusState == .paused else {
            return .result(dialog: "진행 중인 세션이 없습니다.")
        }

        guard appState.canCancel else {
            return .result(dialog: "현재 취소 강도 설정으로 인해 세션을 중지할 수 없습니다.")
        }

        let dataAccess = try AppIntentDataAccess.makeContainer()
        if let dialog = dataAccess.unavailableDialog {
            return .result(dialog: "\(dialog)")
        }
        guard let container = dataAccess.container else {
            return .result(dialog: "\(AppIntentDataAccess.dataStoreUnavailableDialog)")
        }

        await appState.stopSession(modelContext: container.mainContext)

        return .result(dialog: "집중 세션을 중지했습니다.")
    }
}
