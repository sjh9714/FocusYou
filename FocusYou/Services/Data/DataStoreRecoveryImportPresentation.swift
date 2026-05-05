import Foundation

struct DataStoreRecoveryImportSelectionSummary: Equatable {
    let sourceDirectoryName: String
    let sourceStoreFileName: String
    let selectedCandidateCount: Int
    let totalCandidateCount: Int
    let profileCount: Int
    let siteCount: Int
    let appCount: Int
    let scheduleCount: Int
    let importedFocusSessionCount: Int
    let importedBadgeCount: Int
    let skippedFocusSessionCount: Int
    let skippedBadgeCount: Int
    let focusSessionCandidateCount: Int
    let badgeCandidateCount: Int
    let importableFocusSessionCandidateCount: Int
    let importableBadgeCandidateCount: Int
    let duplicateFocusSessionCount: Int
    let duplicateBadgeCount: Int
    let includesFocusSessions: Bool
    let includesBadges: Bool

    var totalImportItemCount: Int {
        profileCount + siteCount + appCount + scheduleCount
            + importedFocusSessionCount + importedBadgeCount
    }

    var canImport: Bool {
        selectedCandidateCount > 0
    }

    var sourceSummary: String {
        "\(sourceDirectoryName)/\(sourceStoreFileName)"
    }

    var selectionSummaryText: String {
        guard selectedCandidateCount > 0 else {
            return String(localized: "선택된 항목이 없습니다.")
        }

        if selectedCandidateCount == totalCandidateCount {
            return String(localized: "프로필 \(totalCandidateCount)개 모두 선택")
        }

        return String(localized: "프로필 \(totalCandidateCount)개 중 \(selectedCandidateCount)개 선택")
    }

    var importSummaryText: String {
        var parts = [
            String(localized: "프로필 \(profileCount)개"),
            String(localized: "사이트 \(siteCount)개"),
            String(localized: "앱 \(appCount)개"),
            String(localized: "스케줄 \(scheduleCount)개"),
        ]

        if importedFocusSessionCount > 0 {
            parts.append(String(localized: "세션 \(importedFocusSessionCount)개"))
        }

        if importedBadgeCount > 0 {
            parts.append(String(localized: "배지 \(importedBadgeCount)개"))
        }

        return String(
            localized: "선택 항목: 총 \(totalImportItemCount)개 (\(parts.joined(separator: ", ")))"
        )
    }

    var skippedSummaryText: String {
        if includesFocusSessions, includesBadges {
            return String(
                localized: "세션 새 항목 \(importableFocusSessionCandidateCount)개와 배지 새 항목 \(importableBadgeCandidateCount)개를 가져옵니다. \(combinedDuplicateText)"
            )
        }

        if includesFocusSessions {
            return String(
                localized: "세션 새 항목 \(importableFocusSessionCandidateCount)개를 가져옵니다. \(focusSessionDuplicateText) 배지 \(badgeCandidateCount)개는 가져오지 않습니다."
            )
        }

        if includesBadges {
            return String(
                localized: "배지 새 항목 \(importableBadgeCandidateCount)개를 가져옵니다. \(badgeDuplicateText) 세션 \(focusSessionCandidateCount)개는 가져오지 않습니다."
            )
        }

        return String(
            localized: "세션 \(skippedFocusSessionCount)개와 배지 \(skippedBadgeCount)개는 가져오지 않습니다."
        )
    }

    var focusSessionOptionText: String {
        String(
            localized: "새 세션 \(importableFocusSessionCandidateCount)개를 추가합니다. \(focusSessionDuplicateText)"
        )
    }

    var badgeOptionText: String {
        String(
            localized: "새 배지 \(importableBadgeCandidateCount)개를 추가합니다. \(badgeDuplicateText)"
        )
    }

    var confirmationMessageText: String {
        let base = String(
            localized: "기존 데이터는 변경하지 않고 선택 항목을 새 항목으로 추가합니다."
        )

        if includesFocusSessions, includesBadges {
            return base + " " + String(
                localized: "세션 새 항목 \(importedFocusSessionCount)개와 배지 새 항목 \(importedBadgeCount)개를 추가합니다. \(combinedDuplicateText)"
            )
        }

        if includesFocusSessions {
            return base + " " + String(
                localized: "세션 새 항목 \(importedFocusSessionCount)개를 추가합니다. \(focusSessionDuplicateText)"
            )
        }

        if includesBadges {
            return base + " " + String(
                localized: "배지 새 항목 \(importedBadgeCount)개를 추가합니다. \(badgeDuplicateText)"
            )
        }

        return base + " " + String(localized: "세션 기록과 배지는 가져오지 않습니다.")
    }

    private var combinedDuplicateText: String {
        if duplicateFocusSessionCount > 0, duplicateBadgeCount > 0 {
            return String(
                localized: "중복 세션 \(duplicateFocusSessionCount)개와 중복 배지 \(duplicateBadgeCount)개는 건너뜁니다."
            )
        }

        if duplicateFocusSessionCount > 0 {
            return String(localized: "중복 세션 \(duplicateFocusSessionCount)개는 건너뜁니다.")
        }

        if duplicateBadgeCount > 0 {
            return String(localized: "중복 배지 \(duplicateBadgeCount)개는 건너뜁니다.")
        }

        return String(localized: "중복 항목은 없습니다.")
    }

    private var focusSessionDuplicateText: String {
        guard duplicateFocusSessionCount > 0 else {
            return String(localized: "중복 항목은 없습니다.")
        }

        return String(localized: "중복 세션 \(duplicateFocusSessionCount)개는 건너뜁니다.")
    }

    private var badgeDuplicateText: String {
        guard duplicateBadgeCount > 0 else {
            return String(localized: "중복 항목은 없습니다.")
        }

        return String(localized: "중복 배지 \(duplicateBadgeCount)개는 건너뜁니다.")
    }
}

extension DataStoreRecoveryImportPreview {
    func selectionSummary(
        selectedCandidateIDs: Set<String>
    ) -> DataStoreRecoveryImportSelectionSummary {
        selectionSummary(
            selection: DataStoreRecoveryImportSelection(
                selectedCandidateIDs: selectedCandidateIDs
            )
        )
    }

    func selectionSummary(
        selection: DataStoreRecoveryImportSelection
    ) -> DataStoreRecoveryImportSelectionSummary {
        let selectedCandidates = profileCandidates
            .filter { selection.selectedCandidateIDs.contains($0.id) }

        return DataStoreRecoveryImportSelectionSummary(
            sourceDirectoryName: sourceDirectoryURL.lastPathComponent,
            sourceStoreFileName: sourceStoreFileName,
            selectedCandidateCount: selectedCandidates.count,
            totalCandidateCount: profileCandidates.count,
            profileCount: selectedCandidates.count,
            siteCount: selectedCandidates.reduce(0) { $0 + $1.siteCount },
            appCount: selectedCandidates.reduce(0) { $0 + $1.appCount },
            scheduleCount: selectedCandidates.reduce(0) { $0 + $1.scheduleCount },
            importedFocusSessionCount: selection.includeFocusSessions ? importableFocusSessionCount : 0,
            importedBadgeCount: selection.includeBadges ? importableBadgeCount : 0,
            skippedFocusSessionCount: selection.includeFocusSessions ? duplicateFocusSessionCount : skippedFocusSessionCount,
            skippedBadgeCount: selection.includeBadges ? duplicateBadgeCount : skippedBadgeCount,
            focusSessionCandidateCount: skippedFocusSessionCount,
            badgeCandidateCount: skippedBadgeCount,
            importableFocusSessionCandidateCount: importableFocusSessionCount,
            importableBadgeCandidateCount: importableBadgeCount,
            duplicateFocusSessionCount: duplicateFocusSessionCount,
            duplicateBadgeCount: duplicateBadgeCount,
            includesFocusSessions: selection.includeFocusSessions,
            includesBadges: selection.includeBadges
        )
    }
}
