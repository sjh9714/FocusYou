import Foundation
import SwiftData

enum AppIntentDataAccessResult {
    case available(ModelContainer)
    case unavailable(String)

    var container: ModelContainer? {
        guard case .available(let container) = self else { return nil }
        return container
    }

    var unavailableDialog: String? {
        guard case .unavailable(let dialog) = self else { return nil }
        return dialog
    }
}

enum AppIntentDataAccess {
    static let dataStoreUnavailableDialog = "데이터 저장소 문제로 이 작업을 안전하게 수행할 수 없습니다. 앱을 열어 백업/복구 안내를 확인하세요."

    static func makeContainer(
        factory: () throws -> AppModelContainerResult = { try AppModelContainerFactory.make() }
    ) throws -> AppIntentDataAccessResult {
        let result = try factory()
        if result.startupDataIssue != nil {
            return .unavailable(dataStoreUnavailableDialog)
        }
        return .available(result.container)
    }
}
