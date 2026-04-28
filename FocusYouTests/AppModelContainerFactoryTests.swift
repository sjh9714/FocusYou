import Foundation
import SwiftData
import Testing
@testable import Focus_You

@Suite("AppModelContainerFactory")
@MainActor
struct AppModelContainerFactoryTests {
    @Test("persistent container succeeds without startup issue")
    func persistentSuccessReturnsContainerWithoutIssue() throws {
        let result = try AppModelContainerFactory.make(
            persistentContainer: {
                try Self.makeInMemoryContainer()
            },
            fallbackContainer: {
                throw TestContainerError.fallbackShouldNotRun
            },
            supportDirectoryURL: Self.supportDirectoryURL
        )

        #expect(result.startupDataIssue == nil)
        let context = result.container.mainContext
        let profile = BlockProfile(name: "Persistent")
        context.insert(profile)
        let profiles = try context.fetch(FetchDescriptor<BlockProfile>())
        #expect(profiles.map(\.name) == ["Persistent"])
    }

    @Test("persistent failure falls back to in-memory container and records issue")
    func persistentFailureFallsBackToInMemoryContainer() throws {
        let result = try AppModelContainerFactory.make(
            persistentContainer: {
                throw TestContainerError.persistentFailed
            },
            fallbackContainer: {
                try Self.makeInMemoryContainer()
            },
            supportDirectoryURL: Self.supportDirectoryURL
        )

        let issue = try #require(result.startupDataIssue)
        #expect(issue.isUsingInMemoryFallback)
        #expect(issue.originalErrorDescription.contains("persistent failed"))
        #expect(issue.supportDirectoryURL == Self.supportDirectoryURL)

        let context = result.container.mainContext
        let profile = BlockProfile(name: "Fallback")
        context.insert(profile)
        let profiles = try context.fetch(FetchDescriptor<BlockProfile>())
        #expect(profiles.map(\.name) == ["Fallback"])
    }

    @Test("fallback policy does not move or delete existing store files")
    func fallbackPolicyDoesNotMoveOrDeleteExistingStoreFiles() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let sentinelURL = tempDirectory.appendingPathComponent("FocusYou.store")
        try Data("do-not-touch".utf8).write(to: sentinelURL)

        _ = try AppModelContainerFactory.make(
            persistentContainer: {
                throw TestContainerError.persistentFailed
            },
            fallbackContainer: {
                try Self.makeInMemoryContainer()
            },
            supportDirectoryURL: tempDirectory
        )

        #expect(FileManager.default.fileExists(atPath: sentinelURL.path))
        let content = try String(contentsOf: sentinelURL, encoding: .utf8)
        #expect(content == "do-not-touch")
    }

    private static let supportDirectoryURL = URL(
        fileURLWithPath: "/tmp/focusyou-support",
        isDirectory: true
    )

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

    private enum TestContainerError: Error, LocalizedError {
        case persistentFailed
        case fallbackShouldNotRun

        var errorDescription: String? {
            switch self {
            case .persistentFailed:
                "persistent failed"
            case .fallbackShouldNotRun:
                "fallback should not run"
            }
        }
    }
}
