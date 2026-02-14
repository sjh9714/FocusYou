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
        XCTAssertEqual(viewModel.errorMessage, "이미 추가된 사이트입니다")
    }

    func testAddWebsiteSuccessClearsInput() throws {
        let context = try makeModelContext()
        viewModel.newWebsiteURL = "test.com"

        viewModel.addWebsite(modelContext: context)

        XCTAssertEqual(viewModel.newWebsiteURL, "")
        XCTAssertNil(viewModel.errorMessage)
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

    // MARK: - 헬퍼

    private func makeModelContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BlockedSite.self, BlockedApp.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}
