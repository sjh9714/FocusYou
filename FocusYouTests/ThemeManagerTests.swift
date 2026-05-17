import XCTest
@testable import Focus_You

final class ThemeManagerTests: XCTestCase {
    private struct RGB {
        let red: Double
        let green: Double
        let blue: Double
    }

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

    @MainActor
    func testDefaultBrandActionColorsMaintainWhiteForegroundContrast() {
        let manager = ThemeManager(defaults: defaults, bundle: .main)
        guard let defaultTheme = manager.availableThemes.first(where: {
            $0.id == Constants.Settings.selectedThemeIDDefault
        }) else {
            XCTFail("Default theme is missing from the theme catalog.")
            return
        }

        let auditedColors = [
            ("primary", defaultTheme.primaryHex),
            ("secondary", defaultTheme.secondaryHex),
            ("accent", defaultTheme.accentHex),
            ("stop", defaultTheme.stopHex),
        ]

        let unsafeColors = auditedColors.compactMap { name, hex -> String? in
            guard let rgb = Self.rgb(from: hex) else {
                return "\(name) has invalid hex \(hex)"
            }

            let ratio = Self.contrastRatio(Self.white, rgb)
            guard ratio >= 4.5 else {
                return "\(name) \(hex) contrast \(String(format: "%.2f", ratio)):1"
            }
            return nil
        }

        XCTAssertTrue(
            unsafeColors.isEmpty,
            "Default theme action colors must support white foreground text: \(unsafeColors.joined(separator: ", "))"
        )
    }

    private static let white = RGB(red: 1, green: 1, blue: 1)

    private static func rgb(from hex: String) -> RGB? {
        let sanitizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard sanitizedHex.count == 6,
              let value = UInt32(sanitizedHex, radix: 16) else {
            return nil
        }

        return RGB(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    private static func contrastRatio(_ foreground: RGB, _ background: RGB) -> Double {
        let foregroundLuminance = relativeLuminance(foreground)
        let backgroundLuminance = relativeLuminance(background)
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func relativeLuminance(_ color: RGB) -> Double {
        let red = linearComponent(color.red)
        let green = linearComponent(color.green)
        let blue = linearComponent(color.blue)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    private static func linearComponent(_ component: Double) -> Double {
        if component <= 0.03928 {
            return component / 12.92
        }
        return pow((component + 0.055) / 1.055, 2.4)
    }
}
