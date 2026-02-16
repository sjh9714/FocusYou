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

    /// 키워드 패턴 모드 토글
    var isKeywordMode = false

    /// URL 정규화 후 차단 사이트 추가 (키워드 모드 시 패턴으로 저장)
    func addWebsite(
        modelContext: ModelContext,
        profile: BlockProfile? = nil
    ) {
        let input = newWebsiteURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if isKeywordMode {
            guard !input.isEmpty else {
                errorMessage = String(localized: "error_enter_keyword")
                return
            }

            let isDuplicate: Bool
            if let profile {
                isDuplicate = profile.blockedSites.contains { $0.domain == input && ($0.isKeywordPattern ?? false) }
            } else {
                let descriptor = FetchDescriptor<BlockedSite>()
                isDuplicate = (try? modelContext.fetch(descriptor))?
                    .contains { $0.domain == input && ($0.isKeywordPattern ?? false) && $0.profile == nil } ?? false
            }
            if isDuplicate {
                errorMessage = String(localized: "error_duplicate_keyword")
                return
            }

            let site = BlockedSite(domain: input, isKeywordPattern: true)
            site.profile = profile
            modelContext.insert(site)
            newWebsiteURL = ""
            errorMessage = nil
            logger.info("키워드 패턴 추가: \(input)")
            return
        }

        let normalized = input.normalizedDomain

        guard !normalized.isEmpty else {
            errorMessage = String(localized: "error_invalid_url")
            return
        }

        // 중복 확인
        let isDuplicate: Bool
        if let profile {
            isDuplicate = profile.blockedSites.contains { $0.domain == normalized }
        } else {
            let descriptor = FetchDescriptor<BlockedSite>()
            isDuplicate = (try? modelContext.fetch(descriptor))?
                .contains { $0.domain == normalized && $0.profile == nil } ?? false
        }
        if isDuplicate {
            errorMessage = String(localized: "error_duplicate_site")
            return
        }

        let site = BlockedSite(domain: normalized)
        site.profile = profile
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
        modelContext: ModelContext,
        profile: BlockProfile? = nil
    ) {
        let bundleId = installedApp.bundleId

        if isBlocked {
            // 중복 확인
            let alreadyBlocked: Bool
            if let profile {
                alreadyBlocked = profile.blockedApps.contains { $0.bundleId == bundleId }
            } else {
                let descriptor = FetchDescriptor<BlockedApp>()
                alreadyBlocked = (try? modelContext.fetch(descriptor))?
                    .contains { $0.bundleId == bundleId && $0.profile == nil } ?? false
            }
            guard !alreadyBlocked else { return }

            let app = BlockedApp(
                bundleId: installedApp.bundleId,
                name: installedApp.name
            )
            app.profile = profile
            modelContext.insert(app)
            logger.info("앱 차단 추가: \(installedApp.name)")
        } else {
            // 제거
            if let profile {
                for app in profile.blockedApps where app.bundleId == bundleId {
                    modelContext.delete(app)
                }
            } else {
                let descriptor = FetchDescriptor<BlockedApp>()
                if let blockedApps = try? modelContext.fetch(descriptor) {
                    for app in blockedApps where app.bundleId == bundleId && app.profile == nil {
                        modelContext.delete(app)
                    }
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
    func applyPreset(
        category: String,
        modelContext: ModelContext,
        profile: BlockProfile? = nil
    ) {
        guard let preset = loadPreset(category: category) else { return }

        let existingSites: [BlockedSite]
        let existingApps: [BlockedApp]

        if let profile {
            existingSites = profile.blockedSites
            existingApps = profile.blockedApps
        } else {
            existingSites = (try? modelContext.fetch(FetchDescriptor<BlockedSite>())) ?? []
            existingApps = (try? modelContext.fetch(FetchDescriptor<BlockedApp>())) ?? []
        }

        // 사이트 추가 (중복 방지)
        for domain in preset.sites {
            let normalized = domain.normalizedDomain
            let exists: Bool
            if profile != nil {
                exists = existingSites.contains { $0.domain == normalized }
            } else {
                exists = existingSites.contains { $0.domain == normalized && $0.profile == nil }
            }
            guard !exists else { continue }

            let site = BlockedSite(domain: normalized, category: category)
            site.profile = profile
            modelContext.insert(site)
        }

        // 앱 추가 (중복 방지)
        for presetApp in preset.apps {
            let bundleId = presetApp.bundleId
            let exists: Bool
            if profile != nil {
                exists = existingApps.contains { $0.bundleId == bundleId }
            } else {
                exists = existingApps.contains { $0.bundleId == bundleId && $0.profile == nil }
            }
            guard !exists else { continue }

            let app = BlockedApp(
                bundleId: presetApp.bundleId,
                name: presetApp.name,
                category: category
            )
            app.profile = profile
            modelContext.insert(app)
        }

        logger.info("프리셋 적용 완료: \(category)")
    }

    /// 카테고리 프리셋 제거
    func removePreset(
        category: String,
        modelContext: ModelContext,
        profile: BlockProfile? = nil
    ) {
        // 해당 카테고리의 사이트 제거
        if let profile {
            for site in profile.blockedSites where site.category == category {
                modelContext.delete(site)
            }
        } else {
            let sitePredicate = #Predicate<BlockedSite> { $0.category == category }
            let siteDescriptor = FetchDescriptor<BlockedSite>(predicate: sitePredicate)
            if let sites = try? modelContext.fetch(siteDescriptor) {
                for site in sites where site.profile == nil {
                    modelContext.delete(site)
                }
            }
        }

        // 해당 카테고리의 앱 제거
        if let profile {
            for app in profile.blockedApps where app.category == category {
                modelContext.delete(app)
            }
        } else {
            let appPredicate = #Predicate<BlockedApp> { $0.category == category }
            let appDescriptor = FetchDescriptor<BlockedApp>(predicate: appPredicate)
            if let apps = try? modelContext.fetch(appDescriptor) {
                for app in apps where app.profile == nil {
                    modelContext.delete(app)
                }
            }
        }

        logger.info("프리셋 제거 완료: \(category)")
    }

    private func belongsToProfile(
        _ candidate: BlockProfile?,
        selectedProfile: BlockProfile?
    ) -> Bool {
        guard let selected = selectedProfile else { return candidate == nil }
        return candidate?.persistentModelID == selected.persistentModelID
    }
}
