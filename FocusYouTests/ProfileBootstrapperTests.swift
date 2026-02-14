import SwiftData
import XCTest
@testable import Focus_You

@MainActor
final class ProfileBootstrapperTests: XCTestCase {
    func testBootstrapCreatesDefaultProfileAndMigratesOrphans() throws {
        let modelContext = try makeModelContext()

        let orphanSite = BlockedSite(domain: "example.com")
        let orphanApp = BlockedApp(bundleId: "com.focusyou.app", name: "Focus App")
        modelContext.insert(orphanSite)
        modelContext.insert(orphanApp)

        let resolvedDefault = ProfileBootstrapper.ensureDefaultProfileAndMigrateOrphans(
            modelContext: modelContext
        )
        let defaultProfile = try XCTUnwrap(resolvedDefault)

        let profiles = try modelContext.fetch(FetchDescriptor<BlockProfile>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertTrue(defaultProfile.isDefault)

        let sites = try modelContext.fetch(FetchDescriptor<BlockedSite>())
        XCTAssertEqual(sites.count, 1)
        XCTAssertEqual(sites.first?.profile?.persistentModelID, defaultProfile.persistentModelID)

        let apps = try modelContext.fetch(FetchDescriptor<BlockedApp>())
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps.first?.profile?.persistentModelID, defaultProfile.persistentModelID)
    }

    func testBootstrapMarksExistingProfileAsDefaultWithoutCreatingNewOne() throws {
        let modelContext = try makeModelContext()
        let existingProfile = BlockProfile(name: "기존 프로필")
        modelContext.insert(existingProfile)

        let resolvedDefault = ProfileBootstrapper.ensureDefaultProfileAndMigrateOrphans(
            modelContext: modelContext
        )

        let profiles = try modelContext.fetch(FetchDescriptor<BlockProfile>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(resolvedDefault?.persistentModelID, existingProfile.persistentModelID)
        XCTAssertTrue(existingProfile.isDefault)
    }

    private func makeModelContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BlockProfile.self,
            BlockedSite.self,
            BlockedApp.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}
