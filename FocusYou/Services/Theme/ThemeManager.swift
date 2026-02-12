import SwiftUI
import os

// MARK: - 테마 관리자
// v0.5 테마 카탈로그 로드 + 사용자 선택 저장

@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "ThemeManager"
    )
    private let defaults: UserDefaults

    private(set) var availableThemes: [AppTheme]
    var selectedThemeID: String {
        didSet {
            guard selectedThemeID != oldValue else { return }
            let normalized = normalizedThemeID(from: selectedThemeID)
            guard normalized == selectedThemeID else {
                selectedThemeID = normalized
                return
            }
            defaults.set(selectedThemeID, forKey: Constants.Settings.selectedThemeIDKey)
            logger.info("테마 변경: \(self.selectedThemeID)")
        }
    }

    var selectedTheme: AppTheme {
        availableThemes.first(where: { $0.id == selectedThemeID }) ?? Self.fallbackTheme
    }

    // MARK: - 테마 색상

    var primary: Color { Color(hex: selectedTheme.primaryHex) }
    var secondary: Color { Color(hex: selectedTheme.secondaryHex) }
    var accent: Color { Color(hex: selectedTheme.accentHex) }
    var background: Color { Color(hex: selectedTheme.backgroundHex) }
    var startButton: Color { primary }
    var stopButton: Color { Color(hex: selectedTheme.stopHex) }
    var pauseButton: Color { accent }
    var progress: Color { primary }
    var completed: Color { secondary }
    var textPrimary: Color { .primary }
    var textSecondary: Color { .secondary }

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults

        let loadedThemes = Self.loadThemes(bundle: bundle)
        let resolvedThemes = loadedThemes.isEmpty ? [Self.fallbackTheme] : loadedThemes
        availableThemes = resolvedThemes

        let savedThemeID = defaults.string(forKey: Constants.Settings.selectedThemeIDKey)
        let candidateThemeID = savedThemeID ?? Constants.Settings.selectedThemeIDDefault
        selectedThemeID = Self.resolveThemeID(
            candidateThemeID,
            from: resolvedThemes
        )

        defaults.set(selectedThemeID, forKey: Constants.Settings.selectedThemeIDKey)
        logger.debug("ThemeManager 초기화: \(self.selectedThemeID)")
    }

    func selectTheme(id: String) {
        selectedThemeID = id
    }

    private func normalizedThemeID(from id: String?) -> String {
        Self.resolveThemeID(id, from: availableThemes)
    }

    private static func resolveThemeID(_ candidate: String?, from themes: [AppTheme]) -> String {
        guard let candidate,
              themes.contains(where: { $0.id == candidate }) else {
            return themes.first(where: { $0.id == Constants.Settings.selectedThemeIDDefault })?.id
                ?? themes.first?.id
                ?? fallbackTheme.id
        }
        return candidate
    }

    private static func loadThemes(bundle: Bundle) -> [AppTheme] {
        let candidateURLs = [
            bundle.url(forResource: "ThemeCatalog", withExtension: "json"),
            bundle.url(forResource: "ThemeCatalog", withExtension: "json", subdirectory: "Themes"),
            bundle.url(forResource: "ThemeCatalog", withExtension: "json", subdirectory: "Resources/Themes"),
        ]

        guard let url = candidateURLs.compactMap({ $0 }).first else {
            return [fallbackTheme]
        }

        guard let data = try? Data(contentsOf: url),
              let themes = try? JSONDecoder().decode([AppTheme].self, from: data),
              !themes.isEmpty else {
            return [fallbackTheme]
        }

        return themes
    }

    private static let fallbackTheme = AppTheme(
        id: "crimson-focus",
        name: "Crimson Focus",
        primaryHex: "#E63946",
        secondaryHex: "#2D6A4F",
        accentHex: "#457B9D",
        stopHex: "#D62828",
        backgroundHex: "#F7F9FC"
    )
}
