import AppIntents
import SwiftData

// MARK: - 프로필 기반 집중 시작 인텐트

struct StartProfileIntent: AppIntent {
    static let title: LocalizedStringResource = "프로필로 집중 시작"
    static let description: IntentDescription = "지정한 프로필 설정으로 집중 세션을 시작합니다."

    @Parameter(title: "프로필 이름")
    var profileName: String

    static var parameterSummary: some ParameterSummary {
        Summary("'\(\.$profileName)' 프로필로 집중 시작")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let appState = AppState.shared else {
            throw IntentError.appNotRunning
        }

        guard appState.focusState == .idle else {
            return .result(dialog: "이미 집중 중입니다.")
        }

        let dataAccess = try AppIntentDataAccess.makeContainer()
        if let dialog = dataAccess.unavailableDialog {
            return .result(dialog: "\(dialog)")
        }
        guard let container = dataAccess.container else {
            return .result(dialog: "\(AppIntentDataAccess.dataStoreUnavailableDialog)")
        }
        let context = container.mainContext

        let profiles = try context.fetch(FetchDescriptor<BlockProfile>())
        guard let profile = profiles.first(where: {
            $0.name.localizedCaseInsensitiveContains(profileName)
        }) else {
            throw IntentError.profileNotFound(profileName)
        }

        await appState.startSessionFromProfile(profile, modelContext: context)

        return .result(dialog: "'\(profile.name)' 프로필로 집중을 시작합니다.")
    }
}
