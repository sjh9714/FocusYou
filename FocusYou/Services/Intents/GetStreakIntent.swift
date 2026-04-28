import AppIntents
import SwiftData

// MARK: - 스트릭 조회 인텐트

struct GetStreakIntent: AppIntent {
    static let title: LocalizedStringResource = "집중 스트릭 확인"
    static let description: IntentDescription = "현재 연속 집중 기록을 확인합니다."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dataAccess = try AppIntentDataAccess.makeContainer()
        if let dialog = dataAccess.unavailableDialog {
            return .result(dialog: "\(dialog)")
        }
        guard let container = dataAccess.container else {
            return .result(dialog: "\(AppIntentDataAccess.dataStoreUnavailableDialog)")
        }
        let context = container.mainContext

        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        let info = StreakCalculator.calculate(from: sessions)

        if info.current > 0 {
            return .result(dialog: "현재 \(info.current)일 연속 집중 중입니다. 최장 기록: \(info.longest)일")
        } else {
            return .result(dialog: "현재 연속 집중 기록이 없습니다. 최장 기록: \(info.longest)일. 오늘 세션을 시작해 보세요!")
        }
    }
}
