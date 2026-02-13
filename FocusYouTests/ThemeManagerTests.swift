import XCTest
@testable import Focus_You

final class ThemeManagerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "FocusYouTests.Theme.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    @MainActor
    func testLoadsThemeCatalogAndDefaultSelection() {
        let manager = ThemeManager(defaults: defaults, bundle: .main)

        XCTAssertFalse(manager.availableThemes.isEmpty)
        XCTAssertTrue(
            manager.availableThemes.contains { $0.id == Constants.Settings.selectedThemeIDDefault }
        )
        XCTAssertEqual(manager.selectedThemeID, Constants.Settings.selectedThemeIDDefault)
    }

    @MainActor
    func testSelectThemePersistsSelection() {
        let manager = ThemeManager(defaults: defaults, bundle: .main)
        guard let targetThemeID = manager.availableThemes.dropFirst().first?.id else {
            XCTFail("테마 카탈로그에 최소 2개 테마가 필요합니다.")
            return
        }

        manager.selectTheme(id: targetThemeID)

        XCTAssertEqual(manager.selectedThemeID, targetThemeID)
        XCTAssertEqual(
            defaults.string(forKey: Constants.Settings.selectedThemeIDKey),
            targetThemeID
        )
    }

    @MainActor
    func testInvalidThemeIDFallsBackToDefault() {
        let manager = ThemeManager(defaults: defaults, bundle: .main)

        manager.selectTheme(id: "invalid-theme-id")

        XCTAssertEqual(manager.selectedThemeID, Constants.Settings.selectedThemeIDDefault)
    }
}
