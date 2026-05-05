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
    let skippedFocusSessionCount: Int
    let skippedBadgeCount: Int

    var totalImportItemCount: Int {
        profileCount + siteCount + appCount + scheduleCount
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
        String(
            localized: "선택 항목: 총 \(totalImportItemCount)개 (프로필 \(profileCount)개, 사이트 \(siteCount)개, 앱 \(appCount)개, 스케줄 \(scheduleCount)개)"
        )
    }

    var skippedSummaryText: String {
        String(
            localized: "세션 \(skippedFocusSessionCount)개와 배지 \(skippedBadgeCount)개는 가져오지 않습니다."
        )
    }
}

extension DataStoreRecoveryImportPreview {
    func selectionSummary(
        selectedCandidateIDs: Set<String>
    ) -> DataStoreRecoveryImportSelectionSummary {
        let selectedCandidates = profileCandidates
            .filter { selectedCandidateIDs.contains($0.id) }

        return DataStoreRecoveryImportSelectionSummary(
            sourceDirectoryName: sourceDirectoryURL.lastPathComponent,
            sourceStoreFileName: sourceStoreFileName,
            selectedCandidateCount: selectedCandidates.count,
            totalCandidateCount: profileCandidates.count,
            profileCount: selectedCandidates.count,
            siteCount: selectedCandidates.reduce(0) { $0 + $1.siteCount },
            appCount: selectedCandidates.reduce(0) { $0 + $1.appCount },
            scheduleCount: selectedCandidates.reduce(0) { $0 + $1.scheduleCount },
            skippedFocusSessionCount: skippedFocusSessionCount,
            skippedBadgeCount: skippedBadgeCount
        )
    }
}
