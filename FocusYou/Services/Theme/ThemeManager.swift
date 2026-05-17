import SwiftUI
import os

// MARK: - 테마 관리자
// 테마 카탈로그 로드 + 사용자 선택 저장

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

    /// 시스템 외관에 따라 라이트/다크 배경을 자동 전환
    var background: Color {
        let lightHex = selectedTheme.backgroundHex
        let darkHex = selectedTheme.backgroundDarkHex ?? "#1C1C1E"
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(isDark ? Color(hex: darkHex) : Color(hex: lightHex))
        })
    }

    /// 라이트 전용 배경 (명시적으로 필요할 때)
    var backgroundLight: Color { Color(hex: selectedTheme.backgroundHex) }

    /// 다크 전용 배경 (명시적으로 필요할 때)
    var backgroundDark: Color {
        if let darkHex = selectedTheme.backgroundDarkHex {
            return Color(hex: darkHex)
        }
        return Color(hex: "#1C1C1E")
    }
    var startButton: Color { primary }
    var stopButton: Color { Color(hex: selectedTheme.stopHex) }
    var pauseButton: Color { accent }
    var progress: Color { primary }
    var completed: Color { secondary }
    var textPrimary: Color { .primary }
    var textSecondary: Color { .secondary }

    // MARK: - 시맨틱 상태 색상

    var warning: Color { .orange }
    var success: Color { .green }
    var danger: Color { .red }

    // MARK: - 파생 스타일

    /// 프라이머리 그라디언트
    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primary.opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 세컨더리 그라디언트
    var secondaryGradient: LinearGradient {
        LinearGradient(
            colors: [secondary, secondary.opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

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

    /// 카테고리별 테마 그룹
    var themesByCategory: [(category: String, themes: [AppTheme])] {
        let grouped = Dictionary(grouping: availableThemes) { $0.category ?? "other" }
        return Constants.ThemeCategory.all.compactMap { cat in
            guard let themes = grouped[cat], !themes.isEmpty else { return nil }
            return (category: cat, themes: themes)
        }
    }

    func selectTheme(id: String) {
        selectedThemeID = id
    }

    /// Pro 제한 시 무료 테마만 반환
    var freeThemes: [AppTheme] {
        Array(availableThemes.prefix(Constants.Subscription.freeThemeLimit))
    }

    /// 특정 테마가 무료인지 확인
    func isThemeFree(_ theme: AppTheme) -> Bool {
        guard let index = availableThemes.firstIndex(where: { $0.id == theme.id }) else {
            return false
        }
        return index < Constants.Subscription.freeThemeLimit
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
        primaryHex: "#B91C2F",
        secondaryHex: "#145C4A",
        accentHex: "#1F5F85",
        stopHex: "#A31621",
        backgroundHex: "#F7FAFC",
        backgroundDarkHex: "#111820"
    )
}
