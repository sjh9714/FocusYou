import Foundation
import SwiftData

struct AppModelContainerResult {
    let container: ModelContainer
    let startupDataIssue: StartupDataIssue?
}

struct StartupDataIssue: Equatable {
    let originalErrorDescription: String
    let isUsingInMemoryFallback: Bool
    let supportDirectoryURL: URL

    var title: String {
        String(localized: "데이터 저장소를 열 수 없습니다")
    }

    var message: String {
        if isUsingInMemoryFallback {
            return String(localized: "기존 데이터는 변경하지 않고 임시 안전 모드로 시작했습니다. 이 세션에서 만든 변경사항은 앱을 종료하면 저장되지 않습니다.")
        }
        return String(localized: "앱 데이터를 열 수 없어 시작을 완료하지 못했습니다.")
    }

    var recoverySuggestion: String {
        String(localized: "앱을 다시 시작해 보세요. 문제가 계속되면 Application Support 폴더를 백업한 뒤 복구 작업을 진행하세요.")
    }
}

enum AppModelContainerFactory {
    typealias ContainerBuilder = () throws -> ModelContainer

    static func make(
        persistentContainer: ContainerBuilder = makePersistentContainer,
        fallbackContainer: ContainerBuilder = makeInMemoryContainer,
        supportDirectoryURL: URL = defaultSupportDirectoryURL
    ) throws -> AppModelContainerResult {
        do {
            let container = try persistentContainer()
            return AppModelContainerResult(
                container: container,
                startupDataIssue: nil
            )
        } catch {
            let persistentError = error
            let fallback = try fallbackContainer()
            let issue = StartupDataIssue(
                originalErrorDescription: errorDescription(for: persistentError),
                isUsingInMemoryFallback: true,
                supportDirectoryURL: supportDirectoryURL
            )
            return AppModelContainerResult(
                container: fallback,
                startupDataIssue: issue
            )
        }
    }

    static var defaultSupportDirectoryURL: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("FocusYou", isDirectory: true)
    }

    private static func makePersistentContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BlockProfile.self,
            BlockedSite.self,
            BlockedApp.self,
            FocusSession.self,
            BlockSchedule.self,
            Badge.self
        )
    }

    private static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: BlockProfile.self,
            BlockedSite.self,
            BlockedApp.self,
            FocusSession.self,
            BlockSchedule.self,
            Badge.self,
            configurations: configuration
        )
    }

    private static func errorDescription(for error: Error) -> String {
        let localized = error.localizedDescription
        if localized != String(describing: error) {
            return localized
        }
        return String(reflecting: error)
    }
}
