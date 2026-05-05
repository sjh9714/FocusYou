import Foundation

struct DataStoreRecoveryImportSelectionSummary: Equatable {
    let sourceDirectoryName: String
    let sourceStoreFileName: String
    let profileCount: Int
    let siteCount: Int
    let appCount: Int
    let scheduleCount: Int
    let skippedFocusSessionCount: Int
    let skippedBadgeCount: Int

    var totalImportItemCount: Int {
        profileCount + siteCount + appCount + scheduleCount
    }

    var sourceSummary: String {
        "\(sourceDirectoryName)/\(sourceStoreFileName)"
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
            profileCount: selectedCandidates.count,
            siteCount: selectedCandidates.reduce(0) { $0 + $1.siteCount },
            appCount: selectedCandidates.reduce(0) { $0 + $1.appCount },
            scheduleCount: selectedCandidates.reduce(0) { $0 + $1.scheduleCount },
            skippedFocusSessionCount: skippedFocusSessionCount,
            skippedBadgeCount: skippedBadgeCount
        )
    }
}

struct DataStoreRecoveryImportExecutionGate: Equatable {
    private(set) var isImportInProgress = false

    mutating func begin() -> Bool {
        guard !isImportInProgress else {
            return false
        }

        isImportInProgress = true
        return true
    }

    mutating func finish() {
        isImportInProgress = false
    }
}
