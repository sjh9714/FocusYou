import Foundation
import SwiftData

struct DataStoreRecoveryImportProfileCandidate: Equatable, Identifiable {
    let id: String
    let displayName: String
    let sourceName: String?
    let isOrphanLegacyBlocks: Bool
    let siteCount: Int
    let appCount: Int
    let scheduleCount: Int

    var detailSummary: String {
        String(
            localized: "사이트 \(siteCount)개, 앱 \(appCount)개, 스케줄 \(scheduleCount)개"
        )
    }
}

struct DataStoreRecoveryImportPreview: Equatable {
    let inspectedAt: Date
    let sourceDirectoryURL: URL
    let sourceStoreFileName: String
    let copiedStoreFiles: [String]
    let profileCandidates: [DataStoreRecoveryImportProfileCandidate]
    let skippedFocusSessionCount: Int
    let skippedBadgeCount: Int

    var statusSummary: String {
        String(
            localized: "가져오기 미리보기: 프로필 후보 \(profileCandidates.count)개, 세션 기록 \(skippedFocusSessionCount)개와 배지 \(skippedBadgeCount)개는 건너뜀"
        )
    }
}

struct DataStoreRecoveryImportResult: Equatable {
    let importedProfileCount: Int
    let importedSiteCount: Int
    let importedAppCount: Int
    let importedScheduleCount: Int
    let skippedFocusSessionCount: Int
    let skippedBadgeCount: Int

    var statusSummary: String {
        String(
            localized: "가져오기 완료: 프로필 \(importedProfileCount)개, 사이트 \(importedSiteCount)개, 앱 \(importedAppCount)개, 스케줄 \(importedScheduleCount)개. 세션 \(skippedFocusSessionCount)개와 배지 \(skippedBadgeCount)개는 건너뜀."
        )
    }
}

enum DataStoreRecoveryImportError: Error, Equatable, LocalizedError {
    case noCandidatesSelected
    case selectedCandidatesNotFound

    var errorDescription: String? {
        switch self {
        case .noCandidatesSelected:
            return String(localized: "가져올 백업 항목을 선택하세요.")
        case .selectedCandidatesNotFound:
            return String(localized: "선택한 백업 항목을 찾을 수 없습니다.")
        }
    }
}

@MainActor
enum DataStoreRecoveryImportService {
    private static let orphanCandidateID = "orphan-legacy-blocks"
    private static let orphanProfileName = "Imported Legacy Blocks"

    static func previewImport(
        at backupDirectoryURL: URL,
        temporaryDirectoryURL: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws -> DataStoreRecoveryImportPreview {
        try DataStoreRecoveryStoreReader.withCopiedStore(
            at: backupDirectoryURL,
            temporaryDirectoryURL: temporaryDirectoryURL,
            fileManager: fileManager
        ) { copiedStore in
            let context = ModelContext(copiedStore.container)
            let candidates = try sourceCandidates(in: context).map(\.candidate)
            return DataStoreRecoveryImportPreview(
                inspectedAt: now,
                sourceDirectoryURL: copiedStore.sourceDirectoryURL,
                sourceStoreFileName: copiedStore.sourceStoreFileName,
                copiedStoreFiles: copiedStore.copiedStoreFiles,
                profileCandidates: candidates,
                skippedFocusSessionCount: try context.fetch(FetchDescriptor<FocusSession>()).count,
                skippedBadgeCount: try context.fetch(FetchDescriptor<Badge>()).count
            )
        }
    }

    static func importSelectedCandidates(
        from backupDirectoryURL: URL,
        selectedCandidateIDs: Set<String>,
        into targetContext: ModelContext,
        temporaryDirectoryURL: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws -> DataStoreRecoveryImportResult {
        guard !selectedCandidateIDs.isEmpty else {
            throw DataStoreRecoveryImportError.noCandidatesSelected
        }

        return try DataStoreRecoveryStoreReader.withCopiedStore(
            at: backupDirectoryURL,
            temporaryDirectoryURL: temporaryDirectoryURL,
            fileManager: fileManager
        ) { copiedStore in
            let sourceContext = ModelContext(copiedStore.container)
            let allCandidates = try sourceCandidates(in: sourceContext)
            let selectedCandidates = allCandidates
                .filter { selectedCandidateIDs.contains($0.candidate.id) }

            guard !selectedCandidates.isEmpty else {
                throw DataStoreRecoveryImportError.selectedCandidatesNotFound
            }

            let existingNames = try targetContext.fetch(FetchDescriptor<BlockProfile>())
                .map(\.name)
            var usedProfileNames = Set(existingNames)
            var importedProfileCount = 0
            var importedSiteCount = 0
            var importedAppCount = 0
            var importedScheduleCount = 0

            for sourceCandidate in selectedCandidates {
                let importedProfile = makeProfile(
                    from: sourceCandidate,
                    usedProfileNames: &usedProfileNames
                )
                targetContext.insert(importedProfile)
                importedProfileCount += 1

                for site in sourceCandidate.sites {
                    let importedSite = copySite(site, profile: importedProfile)
                    targetContext.insert(importedSite)
                    importedSiteCount += 1
                }

                for app in sourceCandidate.apps {
                    let importedApp = copyApp(app, profile: importedProfile)
                    targetContext.insert(importedApp)
                    importedAppCount += 1
                }

                for schedule in sourceCandidate.schedules {
                    let importedSchedule = copySchedule(
                        schedule,
                        profile: importedProfile
                    )
                    targetContext.insert(importedSchedule)
                    importedScheduleCount += 1
                }
            }

            try targetContext.save()

            return DataStoreRecoveryImportResult(
                importedProfileCount: importedProfileCount,
                importedSiteCount: importedSiteCount,
                importedAppCount: importedAppCount,
                importedScheduleCount: importedScheduleCount,
                skippedFocusSessionCount: try sourceContext.fetch(FetchDescriptor<FocusSession>()).count,
                skippedBadgeCount: try sourceContext.fetch(FetchDescriptor<Badge>()).count
            )
        }
    }

    private struct SourceCandidate {
        let candidate: DataStoreRecoveryImportProfileCandidate
        let profile: BlockProfile?
        let sites: [BlockedSite]
        let apps: [BlockedApp]
        let schedules: [BlockSchedule]
    }

    private static func sourceCandidates(
        in context: ModelContext
    ) throws -> [SourceCandidate] {
        let profiles = try context.fetch(
            FetchDescriptor<BlockProfile>(
                sortBy: [
                    SortDescriptor(\.createdAt),
                    SortDescriptor(\.name),
                ]
            )
        )
        let allSites = try context.fetch(
            FetchDescriptor<BlockedSite>(
                sortBy: [
                    SortDescriptor(\.createdAt),
                    SortDescriptor(\.domain),
                ]
            )
        )
        let allApps = try context.fetch(
            FetchDescriptor<BlockedApp>(
                sortBy: [
                    SortDescriptor(\.createdAt),
                    SortDescriptor(\.bundleId),
                ]
            )
        )
        let allSchedules = try context.fetch(
            FetchDescriptor<BlockSchedule>(
                sortBy: [
                    SortDescriptor(\.createdAt),
                    SortDescriptor(\.name),
                ]
            )
        )

        var candidates = profiles.enumerated().map { index, profile in
            let sites = sortedSites(profile.blockedSites)
            let apps = sortedApps(profile.blockedApps)
            let schedules = sortedSchedules(profile.schedules)
            let candidate = DataStoreRecoveryImportProfileCandidate(
                id: profileCandidateID(profile: profile, index: index),
                displayName: profile.name,
                sourceName: profile.name,
                isOrphanLegacyBlocks: false,
                siteCount: sites.count,
                appCount: apps.count,
                scheduleCount: schedules.count
            )
            return SourceCandidate(
                candidate: candidate,
                profile: profile,
                sites: sites,
                apps: apps,
                schedules: schedules
            )
        }

        let orphanSites = sortedSites(allSites.filter { $0.profile == nil })
        let orphanApps = sortedApps(allApps.filter { $0.profile == nil })
        let orphanSchedules = sortedSchedules(allSchedules.filter { $0.profile == nil })
        if !orphanSites.isEmpty || !orphanApps.isEmpty || !orphanSchedules.isEmpty {
            let candidate = DataStoreRecoveryImportProfileCandidate(
                id: orphanCandidateID,
                displayName: orphanProfileName,
                sourceName: nil,
                isOrphanLegacyBlocks: true,
                siteCount: orphanSites.count,
                appCount: orphanApps.count,
                scheduleCount: orphanSchedules.count
            )
            candidates.append(
                SourceCandidate(
                    candidate: candidate,
                    profile: nil,
                    sites: orphanSites,
                    apps: orphanApps,
                    schedules: orphanSchedules
                )
            )
        }

        return candidates
    }

    private static func makeProfile(
        from sourceCandidate: SourceCandidate,
        usedProfileNames: inout Set<String>
    ) -> BlockProfile {
        if let profile = sourceCandidate.profile {
            let importedName = uniqueImportedName(
                for: profile.name,
                usedProfileNames: &usedProfileNames
            )
            let imported = BlockProfile(
                name: importedName,
                icon: profile.icon,
                color: profile.color
            )
            imported.timerMode = profile.timerMode
            imported.focusDuration = profile.focusDuration
            imported.breakDuration = profile.breakDuration
            imported.longBreakDuration = profile.longBreakDuration
            imported.pomodoroCount = profile.pomodoroCount
            imported.isDefault = false
            imported.createdAt = profile.createdAt
            imported.blocklistMode = profile.blocklistMode
            imported.cancelIntensity = profile.cancelIntensity
            imported.cancelLockoutMinutes = profile.cancelLockoutMinutes
            return imported
        }

        let importedName = uniqueImportedName(
            for: orphanProfileName,
            usedProfileNames: &usedProfileNames
        )
        let imported = BlockProfile(
            name: importedName,
            icon: "tray.and.arrow.down.fill",
            color: "#457B9D"
        )
        imported.isDefault = false
        return imported
    }

    private static func copySite(
        _ source: BlockedSite,
        profile: BlockProfile
    ) -> BlockedSite {
        let imported = BlockedSite(
            domain: source.domain,
            category: source.category,
            isKeywordPattern: source.isKeywordPattern ?? false
        )
        imported.domain = source.domain
        imported.isEnabled = source.isEnabled
        imported.isKeywordPattern = source.isKeywordPattern
        imported.createdAt = source.createdAt
        imported.profile = profile
        return imported
    }

    private static func copyApp(
        _ source: BlockedApp,
        profile: BlockProfile
    ) -> BlockedApp {
        let imported = BlockedApp(
            bundleId: source.bundleId,
            name: source.name,
            category: source.category
        )
        imported.isEnabled = source.isEnabled
        imported.createdAt = source.createdAt
        imported.profile = profile
        return imported
    }

    private static func copySchedule(
        _ source: BlockSchedule,
        profile: BlockProfile
    ) -> BlockSchedule {
        let imported = BlockSchedule(
            name: source.name,
            weekdays: source.weekdays,
            startMinuteOfDay: source.startMinuteOfDay,
            endMinuteOfDay: source.endMinuteOfDay
        )
        imported.isEnabled = source.isEnabled
        imported.createdAt = source.createdAt
        imported.profile = profile
        return imported
    }

    private static func uniqueImportedName(
        for sourceName: String,
        usedProfileNames: inout Set<String>
    ) -> String {
        let baseName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = baseName.isEmpty ? orphanProfileName : baseName

        let firstCandidate = "\(fallbackName) (Imported)"
        if !usedProfileNames.contains(fallbackName) {
            usedProfileNames.insert(fallbackName)
            return fallbackName
        }

        if !usedProfileNames.contains(firstCandidate) {
            usedProfileNames.insert(firstCandidate)
            return firstCandidate
        }

        var suffix = 2
        while true {
            let candidate = "\(fallbackName) (Imported \(suffix))"
            if !usedProfileNames.contains(candidate) {
                usedProfileNames.insert(candidate)
                return candidate
            }
            suffix += 1
        }
    }

    private static func profileCandidateID(
        profile: BlockProfile,
        index: Int
    ) -> String {
        let timestamp = profile.createdAt.timeIntervalSince1970
        return "profile-\(index)-\(timestamp)-\(profile.name)"
    }

    private static func sortedSites(_ sites: [BlockedSite]) -> [BlockedSite] {
        sites.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.domain < $1.domain
        }
    }

    private static func sortedApps(_ apps: [BlockedApp]) -> [BlockedApp] {
        apps.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.bundleId < $1.bundleId
        }
    }

    private static func sortedSchedules(_ schedules: [BlockSchedule]) -> [BlockSchedule] {
        schedules.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.name < $1.name
        }
    }
}
