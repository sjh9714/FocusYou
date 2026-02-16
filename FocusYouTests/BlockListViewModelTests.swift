import AppKit
import SwiftData
import XCTest
@testable import Focus_You

@MainActor
final class BlockListViewModelTests: XCTestCase {
    private var viewModel: BlockListViewModel!

    override func setUp() {
        super.setUp()
        viewModel = BlockListViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - 웹사이트 추가

    func testAddWebsiteEmptyURLSetsError() throws {
        let context = try makeModelContext()
        viewModel.newWebsiteURL = ""

        viewModel.addWebsite(modelContext: context)

        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testAddWebsiteNormalizesAndInserts() throws {
        let context = try makeModelContext()
        viewModel.newWebsiteURL = "https://www.example.com/path"

        viewModel.addWebsite(modelContext: context)

        let descriptor = FetchDescriptor<BlockedSite>()
        let sites = try context.fetch(descriptor)
        XCTAssertEqual(sites.count, 1)
        XCTAssertEqual(sites.first?.domain, "example.com")
    }

    func testAddWebsiteDuplicateSetsError() throws {
        let context = try makeModelContext()

        // 첫 번째 추가
        viewModel.newWebsiteURL = "example.com"
        viewModel.addWebsite(modelContext: context)
        XCTAssertNil(viewModel.errorMessage)

        // 중복 추가
        viewModel.newWebsiteURL = "example.com"
        viewModel.addWebsite(modelContext: context)
        XCTAssertEqual(viewModel.errorMessage, String(localized: "error_duplicate_site"))
    }

    func testAddWebsiteSuccessClearsInput() throws {
        let context = try makeModelContext()
        viewModel.newWebsiteURL = "test.com"

        viewModel.addWebsite(modelContext: context)

        XCTAssertEqual(viewModel.newWebsiteURL, "")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddWebsiteAllowsSameDomainAcrossDifferentProfiles() throws {
        let context = try makeModelContext()
        let profileA = BlockProfile(name: "A")
        let profileB = BlockProfile(name: "B")
        context.insert(profileA)
        context.insert(profileB)

        viewModel.newWebsiteURL = "dup.com"
        viewModel.addWebsite(modelContext: context, profile: profileA)
        XCTAssertNil(viewModel.errorMessage)

        viewModel.newWebsiteURL = "dup.com"
        viewModel.addWebsite(modelContext: context, profile: profileB)
        XCTAssertNil(viewModel.errorMessage)

        let descriptor = FetchDescriptor<BlockedSite>()
        let sites = try context.fetch(descriptor)
        XCTAssertEqual(sites.count, 2)
    }

    func testAddWebsiteDuplicateWithinSameProfileSetsError() throws {
        let context = try makeModelContext()
        let profile = BlockProfile(name: "A")
        context.insert(profile)

        viewModel.newWebsiteURL = "same.com"
        viewModel.addWebsite(modelContext: context, profile: profile)
        XCTAssertNil(viewModel.errorMessage)

        viewModel.newWebsiteURL = "same.com"
        viewModel.addWebsite(modelContext: context, profile: profile)
        XCTAssertEqual(viewModel.errorMessage, String(localized: "error_duplicate_site"))
    }

    // MARK: - 웹사이트 삭제

    func testDeleteSites() throws {
        let context = try makeModelContext()

        let site1 = BlockedSite(domain: "a.com")
        let site2 = BlockedSite(domain: "b.com")
        context.insert(site1)
        context.insert(site2)

        viewModel.deleteSites([site1, site2], modelContext: context)

        let descriptor = FetchDescriptor<BlockedSite>()
        let remaining = try context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 0)
    }

    // MARK: - 앱 토글 (프로필 스코프)

    func testToggleAppRemoveOnlyAffectsSelectedProfile() throws {
        let context = try makeModelContext()
        let profileA = BlockProfile(name: "A")
        let profileB = BlockProfile(name: "B")
        context.insert(profileA)
        context.insert(profileB)

        let appInfo = BlockListViewModel.InstalledApp(
            id: "com.focusyou.app",
            bundleId: "com.focusyou.app",
            name: "Focus App",
            icon: NSImage(size: NSSize(width: 16, height: 16))
        )

        viewModel.toggleApp(appInfo, isBlocked: true, modelContext: context, profile: profileA)
        viewModel.toggleApp(appInfo, isBlocked: true, modelContext: context, profile: profileB)

        var descriptor = FetchDescriptor<BlockedApp>()
        var apps = try context.fetch(descriptor)
        XCTAssertEqual(apps.count, 2)

        viewModel.toggleApp(appInfo, isBlocked: false, modelContext: context, profile: profileA)

        descriptor = FetchDescriptor<BlockedApp>()
        apps = try context.fetch(descriptor)
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps.first?.profile?.persistentModelID, profileB.persistentModelID)
    }

    // MARK: - 헬퍼

    private func makeModelContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BlockProfile.self, BlockedSite.self, BlockedApp.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}
