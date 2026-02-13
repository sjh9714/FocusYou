import SwiftUI
import SwiftData
import AppKit
import os

// MARK: - 차단 목록 ViewModel
// URL 추가, 앱 스캔, 카테고리 프리셋 관리

@MainActor
@Observable
final class BlockListViewModel {
    /// 새 웹사이트 URL 입력
    var newWebsiteURL: String = ""

    /// 에러 메시지
    var errorMessage: String?

    /// 검색 텍스트 (앱 목록 필터)
    var appSearchText: String = ""

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "BlockListViewModel"
    )

    // MARK: - 웹사이트 관리

    /// URL 정규화 후 차단 사이트 추가
    func addWebsite(modelContext: ModelContext) {
        let normalized = newWebsiteURL.normalizedDomain

        guard !normalized.isEmpty else {
            errorMessage = "올바른 URL을 입력해주세요"
            return
        }

        // 중복 확인
        let predicate = #Predicate<BlockedSite> { $0.domain == normalized }
        let descriptor = FetchDescriptor<BlockedSite>(predicate: predicate)

        if let count = try? modelContext.fetchCount(descriptor), count > 0 {
            errorMessage = "이미 추가된 사이트입니다"
            return
        }

        let site = BlockedSite(domain: normalized)
        modelContext.insert(site)
        newWebsiteURL = ""
        errorMessage = nil
        logger.info("사이트 추가: \(normalized)")
    }

    /// 사이트 삭제
    func deleteSites(_ sites: [BlockedSite], modelContext: ModelContext) {
        for site in sites {
            modelContext.delete(site)
        }
    }

    // MARK: - 앱 관리

    /// 설치된 앱 정보
    struct InstalledApp: Identifiable {
        let id: String  // bundleId
        let bundleId: String
        let name: String
        let icon: NSImage
    }

    /// /Applications 스캔하여 설치된 앱 목록 반환
    /// Finder, 시스템 설정은 제외 (CLAUDE.md 규칙)
    func scanInstalledApps() -> [InstalledApp] {
        let fileManager = FileManager.default
        let applicationsURL = URL(fileURLWithPath: "/Applications")

        // 제외할 번들 ID (시스템 필수 앱)
        let excludedBundleIds: Set<String> = [
            "com.apple.finder",
            "com.apple.systempreferences",
            "com.apple.SystemPreferences",
            "com.apple.Safari",  // 브라우저는 hosts로 차단하므로 앱 차단 불필요
        ]

        var apps = [InstalledApp]()

        guard let contents = try? fileManager.contentsOfDirectory(
            at: applicationsURL,
            includingPropertiesForKeys: nil
        ) else {
            return apps
        }

        for url in contents where url.pathExtension == "app" {
            guard let bundle = Bundle(url: url),
                  let bundleId = bundle.bundleIdentifier,
                  !excludedBundleIds.contains(bundleId) else {
                continue
            }

            let name = url.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: url.path)

            apps.append(InstalledApp(
                id: bundleId,
                bundleId: bundleId,
                name: name,
                icon: icon
            ))
        }

        return apps.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// 앱 차단 토글
    func toggleApp(
        _ installedApp: InstalledApp,
        isBlocked: Bool,
        modelContext: ModelContext
    ) {
        if isBlocked {
            // 중복 확인 (applyPreset과 동일 패턴)
            let bundleId = installedApp.bundleId
            let predicate = #Predicate<BlockedApp> { $0.bundleId == bundleId }
            let descriptor = FetchDescriptor<BlockedApp>(predicate: predicate)
            if let count = try? modelContext.fetchCount(descriptor), count > 0 {
                return
            }

            let app = BlockedApp(
                bundleId: installedApp.bundleId,
                name: installedApp.name
            )
            modelContext.insert(app)
            logger.info("앱 차단 추가: \(installedApp.name)")
        } else {
            // 제거
            let bundleId = installedApp.bundleId
            let predicate = #Predicate<BlockedApp> { $0.bundleId == bundleId }
            let descriptor = FetchDescriptor<BlockedApp>(predicate: predicate)

            if let blockedApps = try? modelContext.fetch(descriptor) {
                for app in blockedApps {
                    modelContext.delete(app)
                }
            }
            logger.info("앱 차단 제거: \(installedApp.name)")
        }
    }

    // MARK: - 카테고리 프리셋

    /// 프리셋 데이터 구조
    struct PresetData: Decodable {
        let category: String
        let sites: [String]
        let apps: [PresetApp]

        struct PresetApp: Decodable {
            let bundleId: String
            let name: String
        }
    }

    /// 카테고리 프리셋 로드
    func loadPreset(category: String) -> PresetData? {
        let fileName: String
        switch category {
        case Constants.Category.sns: fileName = "sns"
        case Constants.Category.news: fileName = "news"
        case Constants.Category.video: fileName = "video"
        case Constants.Category.games: fileName = "games"
        default: return nil
        }

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let preset = try? JSONDecoder().decode(PresetData.self, from: data) else {
            logger.error("프리셋 로드 실패: \(category)")
            return nil
        }

        return preset
    }

    /// 카테고리 프리셋 일괄 적용
    func applyPreset(category: String, modelContext: ModelContext) {
        guard let preset = loadPreset(category: category) else { return }

        // 사이트 추가 (중복 방지)
        for domain in preset.sites {
            let normalized = domain.normalizedDomain
            let predicate = #Predicate<BlockedSite> { $0.domain == normalized }
            let descriptor = FetchDescriptor<BlockedSite>(predicate: predicate)

            if let count = try? modelContext.fetchCount(descriptor), count > 0 {
                continue
            }

            let site = BlockedSite(domain: normalized, category: category)
            modelContext.insert(site)
        }

        // 앱 추가 (중복 방지)
        for presetApp in preset.apps {
            let bundleId = presetApp.bundleId
            let predicate = #Predicate<BlockedApp> { $0.bundleId == bundleId }
            let descriptor = FetchDescriptor<BlockedApp>(predicate: predicate)

            if let count = try? modelContext.fetchCount(descriptor), count > 0 {
                continue
            }

            let app = BlockedApp(
                bundleId: presetApp.bundleId,
                name: presetApp.name,
                category: category
            )
            modelContext.insert(app)
        }

        logger.info("프리셋 적용 완료: \(category)")
    }

    /// 카테고리 프리셋 제거
    func removePreset(category: String, modelContext: ModelContext) {
        // 해당 카테고리의 사이트 제거
        let sitePredicate = #Predicate<BlockedSite> { $0.category == category }
        let siteDescriptor = FetchDescriptor<BlockedSite>(predicate: sitePredicate)

        if let sites = try? modelContext.fetch(siteDescriptor) {
            for site in sites {
                modelContext.delete(site)
            }
        }

        // 해당 카테고리의 앱 제거
        let appPredicate = #Predicate<BlockedApp> { $0.category == category }
        let appDescriptor = FetchDescriptor<BlockedApp>(predicate: appPredicate)

        if let apps = try? modelContext.fetch(appDescriptor) {
            for app in apps {
                modelContext.delete(app)
            }
        }

        logger.info("프리셋 제거 완료: \(category)")
    }
}
