import AppIntents
import SwiftData

// MARK: - 집중 시작 인텐트

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "집중 시작"
    static let description: IntentDescription = "지정한 시간만큼 집중 세션을 시작합니다."

    @Parameter(title: "시간 (분)", default: 25)
    var durationMinutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("집중 시작 (\(\.$durationMinutes)분)")
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
        let profile = profiles.first(where: \.isDefault) ?? profiles.first

        let sites = profile?.blockedSites.filter(\.isEnabled) ?? []
        let apps = profile?.blockedApps.filter(\.isEnabled) ?? []

        let duration = TimeInterval(durationMinutes * 60)

        await appState.startFocusSession(
            duration: duration,
            sites: sites,
            apps: apps,
            modelContext: context
        )

        return .result(dialog: "\(durationMinutes)분 집중을 시작합니다.")
    }
}
