import Foundation
import SwiftData
import os

// MARK: - 기본 프로필/레거시 데이터 부트스트랩

@MainActor
enum ProfileBootstrapper {
    private static let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "ProfileBootstrapper"
    )

    /// 기본 프로필을 보장하고, profile이 없는 기존 차단 항목을 기본 프로필로 이관합니다.
    @discardableResult
    static func ensureDefaultProfileAndMigrateOrphans(
        modelContext: ModelContext
    ) -> BlockProfile? {
        do {
            let profileDescriptor = FetchDescriptor<BlockProfile>()
            let profiles = try modelContext.fetch(profileDescriptor)

            let defaultProfile = try resolveDefaultProfile(
                existingProfiles: profiles,
                modelContext: modelContext
            )
            normalizeDefaultProfileFlags(
                profiles: profiles,
                defaultProfile: defaultProfile
            )

            let migratedSites = try migrateOrphanSites(
                to: defaultProfile,
                modelContext: modelContext
            )
            let migratedApps = try migrateOrphanApps(
                to: defaultProfile,
                modelContext: modelContext
            )

            if modelContext.hasChanges {
                try modelContext.save()
            }

            logger.info(
                "프로필 부트스트랩 완료: default=\(defaultProfile.name, privacy: .public), migratedSites=\(migratedSites), migratedApps=\(migratedApps)"
            )
            return defaultProfile
        } catch {
            logger.error("프로필 부트스트랩 실패: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func resolveDefaultProfile(
        existingProfiles: [BlockProfile],
        modelContext: ModelContext
    ) throws -> BlockProfile {
        if let defaultProfile = existingProfiles.first(where: \.isDefault) {
            return defaultProfile
        }

        if let firstProfile = existingProfiles.first {
            firstProfile.isDefault = true
            return firstProfile
        }

        let defaultProfile = BlockProfile.createDefault()
        modelContext.insert(defaultProfile)
        return defaultProfile
    }

    private static func normalizeDefaultProfileFlags(
        profiles: [BlockProfile],
        defaultProfile: BlockProfile
    ) {
        for profile in profiles where profile.persistentModelID != defaultProfile.persistentModelID {
            if profile.isDefault {
                profile.isDefault = false
            }
        }
    }

    private static func migrateOrphanSites(
        to defaultProfile: BlockProfile,
        modelContext: ModelContext
    ) throws -> Int {
        let siteDescriptor = FetchDescriptor<BlockedSite>()
        let orphanSites = try modelContext.fetch(siteDescriptor).filter { $0.profile == nil }

        for site in orphanSites {
            site.profile = defaultProfile
        }

        return orphanSites.count
    }

    private static func migrateOrphanApps(
        to defaultProfile: BlockProfile,
        modelContext: ModelContext
    ) throws -> Int {
        let appDescriptor = FetchDescriptor<BlockedApp>()
        let orphanApps = try modelContext.fetch(appDescriptor).filter { $0.profile == nil }

        for app in orphanApps {
            app.profile = defaultProfile
        }

        return orphanApps.count
    }
}
