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
    let duplicateFocusSessionCount: Int
    let duplicateBadgeCount: Int

    init(
        inspectedAt: Date,
        sourceDirectoryURL: URL,
        sourceStoreFileName: String,
        copiedStoreFiles: [String],
        profileCandidates: [DataStoreRecoveryImportProfileCandidate],
        skippedFocusSessionCount: Int,
        skippedBadgeCount: Int,
        duplicateFocusSessionCount: Int = 0,
        duplicateBadgeCount: Int = 0
    ) {
        self.inspectedAt = inspectedAt
        self.sourceDirectoryURL = sourceDirectoryURL
        self.sourceStoreFileName = sourceStoreFileName
        self.copiedStoreFiles = copiedStoreFiles
        self.profileCandidates = profileCandidates
        self.skippedFocusSessionCount = skippedFocusSessionCount
        self.skippedBadgeCount = skippedBadgeCount
        self.duplicateFocusSessionCount = duplicateFocusSessionCount
        self.duplicateBadgeCount = duplicateBadgeCount
    }

    var importableFocusSessionCount: Int {
        max(0, skippedFocusSessionCount - duplicateFocusSessionCount)
    }

    var importableBadgeCount: Int {
        max(0, skippedBadgeCount - duplicateBadgeCount)
    }

    var statusSummary: String {
        String(
            localized: "가져오기 미리보기: 프로필 후보 \(profileCandidates.count)개, 세션 새 항목 \(importableFocusSessionCount)개/중복 \(duplicateFocusSessionCount)개, 배지 새 항목 \(importableBadgeCount)개/중복 \(duplicateBadgeCount)개"
        )
    }
}

struct DataStoreRecoveryImportSelection: Equatable {
    let selectedCandidateIDs: Set<String>
    let includeFocusSessions: Bool
    let includeBadges: Bool

    init(
        selectedCandidateIDs: Set<String>,
        includeFocusSessions: Bool = false,
        includeBadges: Bool = false
    ) {
        self.selectedCandidateIDs = selectedCandidateIDs
        self.includeFocusSessions = includeFocusSessions
        self.includeBadges = includeBadges
    }
}

struct DataStoreRecoveryImportResult: Equatable {
    let importedProfileCount: Int
    let importedSiteCount: Int
    let importedAppCount: Int
    let importedScheduleCount: Int
    let importedFocusSessionCount: Int
    let importedBadgeCount: Int
    let skippedFocusSessionCount: Int
    let skippedBadgeCount: Int

    var statusSummary: String {
        String(
            localized: "가져오기 완료: 프로필 \(importedProfileCount)개, 사이트 \(importedSiteCount)개, 앱 \(importedAppCount)개, 스케줄 \(importedScheduleCount)개, 세션 \(importedFocusSessionCount)개, 배지 \(importedBadgeCount)개. 세션 \(skippedFocusSessionCount)개와 배지 \(skippedBadgeCount)개는 건너뜀."
        )
    }
}

enum DataStoreRecoveryImportError: Error, Equatable, LocalizedError {
    case noCandidatesSelected
    case selectedCandidatesNotFound
    case failedToSaveImport(String)

    var errorDescription: String? {
        switch self {
        case .noCandidatesSelected:
            return String(localized: "가져올 백업 항목을 선택하세요.")
        case .selectedCandidatesNotFound:
            return String(localized: "선택한 백업 항목을 찾을 수 없습니다.")
        case .failedToSaveImport(let reason):
            return String(localized: "가져온 데이터를 저장할 수 없습니다: \(reason)")
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
            let context = copiedStore.context
            let candidates = try sourceCandidates(in: context).map(\.candidate)
            let sourceFocusSessions = try sourceFocusSessions(in: context)
            let sourceBadges = try sourceBadges(in: context)
            return DataStoreRecoveryImportPreview(
                inspectedAt: now,
                sourceDirectoryURL: copiedStore.sourceDirectoryURL,
                sourceStoreFileName: copiedStore.sourceStoreFileName,
                copiedStoreFiles: copiedStore.copiedStoreFiles,
                profileCandidates: candidates,
                skippedFocusSessionCount: sourceFocusSessions.count,
                skippedBadgeCount: sourceBadges.count
            )
        }
    }

    static func previewImport(
        at backupDirectoryURL: URL,
        into targetContext: ModelContext,
        temporaryDirectoryURL: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws -> DataStoreRecoveryImportPreview {
        try DataStoreRecoveryStoreReader.withCopiedStore(
            at: backupDirectoryURL,
            temporaryDirectoryURL: temporaryDirectoryURL,
            fileManager: fileManager
        ) { copiedStore in
            let context = copiedStore.context
            let candidates = try sourceCandidates(in: context).map(\.candidate)
            let sourceFocusSessions = try sourceFocusSessions(in: context)
            let sourceBadges = try sourceBadges(in: context)
            return DataStoreRecoveryImportPreview(
                inspectedAt: now,
                sourceDirectoryURL: copiedStore.sourceDirectoryURL,
                sourceStoreFileName: copiedStore.sourceStoreFileName,
                copiedStoreFiles: copiedStore.copiedStoreFiles,
                profileCandidates: candidates,
                skippedFocusSessionCount: sourceFocusSessions.count,
                skippedBadgeCount: sourceBadges.count,
                duplicateFocusSessionCount: try duplicateFocusSessionCount(
                    sourceFocusSessions,
                    in: targetContext
                ),
                duplicateBadgeCount: try duplicateBadgeCount(
                    sourceBadges,
                    in: targetContext
                )
            )
        }
    }

    static func importSelectedCandidates(
        from backupDirectoryURL: URL,
        selectedCandidateIDs: Set<String>,
        into targetContext: ModelContext,
        temporaryDirectoryURL: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default,
        now: Date = Date(),
        save: (ModelContext) throws -> Void = { context in
            try context.save()
        }
    ) throws -> DataStoreRecoveryImportResult {
        try importSelectedCandidates(
            from: backupDirectoryURL,
            selection: DataStoreRecoveryImportSelection(
                selectedCandidateIDs: selectedCandidateIDs
            ),
            into: targetContext,
            temporaryDirectoryURL: temporaryDirectoryURL,
            fileManager: fileManager,
            now: now,
            save: save
        )
    }

    static func importSelectedCandidates(
        from backupDirectoryURL: URL,
        selection: DataStoreRecoveryImportSelection,
        into targetContext: ModelContext,
        temporaryDirectoryURL: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default,
        now: Date = Date(),
        save: (ModelContext) throws -> Void = { context in
            try context.save()
        }
    ) throws -> DataStoreRecoveryImportResult {
        guard !selection.selectedCandidateIDs.isEmpty else {
            throw DataStoreRecoveryImportError.noCandidatesSelected
        }

        return try DataStoreRecoveryStoreReader.withCopiedStore(
            at: backupDirectoryURL,
            temporaryDirectoryURL: temporaryDirectoryURL,
            fileManager: fileManager
        ) { copiedStore in
            let sourceContext = copiedStore.context
            let allCandidates = try sourceCandidates(in: sourceContext)
            let selectedCandidates = allCandidates
                .filter { selection.selectedCandidateIDs.contains($0.candidate.id) }
            let resolvedCandidateIDs = Set(selectedCandidates.map(\.candidate.id))

            guard !selectedCandidates.isEmpty,
                  resolvedCandidateIDs == selection.selectedCandidateIDs else {
                throw DataStoreRecoveryImportError.selectedCandidatesNotFound
            }

            let sourceFocusSessions = try sourceFocusSessions(in: sourceContext)
            let sourceBadges = try sourceBadges(in: sourceContext)
            let existingNames = try targetContext.fetch(FetchDescriptor<BlockProfile>())
                .map(\.name)
            var usedProfileNames = Set(existingNames)
            var existingSessionKeys = Set(
                try targetContext.fetch(FetchDescriptor<FocusSession>())
                    .map(FocusSessionImportKey.init)
            )
            var existingBadgeMilestoneIDs = Set(
                try targetContext.fetch(FetchDescriptor<Badge>())
                    .map(\.milestoneID)
            )
            var importedProfileCount = 0
            var importedSiteCount = 0
            var importedAppCount = 0
            var importedScheduleCount = 0
            var importedFocusSessionCount = 0
            var importedBadgeCount = 0
            var skippedFocusSessionCount = sourceFocusSessions.count
            var skippedBadgeCount = sourceBadges.count

            do {
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

                if selection.includeFocusSessions {
                    skippedFocusSessionCount = 0
                    for sourceSession in sourceFocusSessions {
                        let key = FocusSessionImportKey(session: sourceSession)
                        guard !existingSessionKeys.contains(key) else {
                            skippedFocusSessionCount += 1
                            continue
                        }

                        let importedSession = copyFocusSession(sourceSession)
                        targetContext.insert(importedSession)
                        existingSessionKeys.insert(key)
                        importedFocusSessionCount += 1
                    }
                }

                if selection.includeBadges {
                    skippedBadgeCount = 0
                    for sourceBadge in sourceBadges {
                        guard !existingBadgeMilestoneIDs.contains(sourceBadge.milestoneID) else {
                            skippedBadgeCount += 1
                            continue
                        }

                        let importedBadge = copyBadge(sourceBadge)
                        targetContext.insert(importedBadge)
                        existingBadgeMilestoneIDs.insert(sourceBadge.milestoneID)
                        importedBadgeCount += 1
                    }
                }

                try save(targetContext)
            } catch {
                targetContext.rollback()
                throw DataStoreRecoveryImportError.failedToSaveImport(error.localizedDescription)
            }

            return DataStoreRecoveryImportResult(
                importedProfileCount: importedProfileCount,
                importedSiteCount: importedSiteCount,
                importedAppCount: importedAppCount,
                importedScheduleCount: importedScheduleCount,
                importedFocusSessionCount: importedFocusSessionCount,
                importedBadgeCount: importedBadgeCount,
                skippedFocusSessionCount: skippedFocusSessionCount,
                skippedBadgeCount: skippedBadgeCount
            )
        }
    }

    private struct FocusSessionImportKey: Hashable {
        let timerMode: String
        let startedAt: Date
        let endedAt: Date?
        let plannedDuration: Int?
        let actualDuration: Int
        let overflowDuration: Int
        let sessionType: String
        let wasCompleted: Bool

        init(session: FocusSession) {
            self.timerMode = session.timerMode
            self.startedAt = session.startedAt
            self.endedAt = session.endedAt
            self.plannedDuration = session.plannedDuration
            self.actualDuration = session.actualDuration
            self.overflowDuration = session.overflowDuration
            self.sessionType = session.sessionType
            self.wasCompleted = session.wasCompleted
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

    private static func copyFocusSession(_ source: FocusSession) -> FocusSession {
        let imported = FocusSession(
            timerMode: source.timerMode,
            plannedDuration: source.plannedDuration
        )
        imported.profileName = source.profileName
        imported.startedAt = source.startedAt
        imported.endedAt = source.endedAt
        imported.actualDuration = source.actualDuration
        imported.overflowDuration = source.overflowDuration
        imported.sessionType = source.sessionType
        imported.wasCompleted = source.wasCompleted
        imported.intention = source.intention
        imported.retrospectEmoji = source.retrospectEmoji
        imported.retrospectText = source.retrospectText
        imported.retrospectRating = source.retrospectRating
        imported.calendarEventID = nil
        return imported
    }

    private static func copyBadge(_ source: Badge) -> Badge {
        let imported = Badge(
            milestoneID: source.milestoneID,
            title: source.title,
            emoji: source.emoji,
            desc: source.desc
        )
        imported.achievedAt = source.achievedAt
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

    private static func sourceFocusSessions(in context: ModelContext) throws -> [FocusSession] {
        try context.fetch(
            FetchDescriptor<FocusSession>(
                sortBy: [
                    SortDescriptor(\.startedAt),
                    SortDescriptor(\.timerMode),
                ]
            )
        )
    }

    private static func sourceBadges(in context: ModelContext) throws -> [Badge] {
        try context.fetch(
            FetchDescriptor<Badge>(
                sortBy: [
                    SortDescriptor(\.achievedAt),
                    SortDescriptor(\.milestoneID),
                ]
            )
        )
    }

    private static func duplicateFocusSessionCount(
        _ sourceSessions: [FocusSession],
        in targetContext: ModelContext
    ) throws -> Int {
        var existingKeys = Set(
            try targetContext.fetch(FetchDescriptor<FocusSession>())
                .map(FocusSessionImportKey.init)
        )
        var duplicateCount = 0

        for sourceSession in sourceSessions {
            let key = FocusSessionImportKey(session: sourceSession)
            guard !existingKeys.contains(key) else {
                duplicateCount += 1
                continue
            }
            existingKeys.insert(key)
        }

        return duplicateCount
    }

    private static func duplicateBadgeCount(
        _ sourceBadges: [Badge],
        in targetContext: ModelContext
    ) throws -> Int {
        var existingMilestoneIDs = Set(
            try targetContext.fetch(FetchDescriptor<Badge>())
                .map(\.milestoneID)
        )
        var duplicateCount = 0

        for sourceBadge in sourceBadges {
            guard !existingMilestoneIDs.contains(sourceBadge.milestoneID) else {
                duplicateCount += 1
                continue
            }
            existingMilestoneIDs.insert(sourceBadge.milestoneID)
        }

        return duplicateCount
    }
}
