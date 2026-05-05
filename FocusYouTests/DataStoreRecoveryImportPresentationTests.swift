import Foundation
import Testing
@testable import Focus_You

@Suite("DataStoreRecoveryImportPresentation")
struct DataStoreRecoveryImportPresentationTests {
    @Test("selection summary counts selected candidates and skipped history")
    func selectionSummaryCountsSelectedCandidatesAndSkippedHistory() {
        let profile = DataStoreRecoveryImportProfileCandidate(
            id: "profile",
            displayName: "Deep Work",
            sourceName: "Deep Work",
            isOrphanLegacyBlocks: false,
            siteCount: 2,
            appCount: 3,
            scheduleCount: 1
        )
        let orphan = DataStoreRecoveryImportProfileCandidate(
            id: "orphan",
            displayName: "Imported Legacy Blocks",
            sourceName: nil,
            isOrphanLegacyBlocks: true,
            siteCount: 1,
            appCount: 0,
            scheduleCount: 2
        )
        let preview = DataStoreRecoveryImportPreview(
            inspectedAt: .distantPast,
            sourceDirectoryURL: URL(fileURLWithPath: "/tmp/FocusYouBackup-20260505"),
            sourceStoreFileName: "default.store",
            copiedStoreFiles: ["default.store", "default.store-wal"],
            profileCandidates: [profile, orphan],
            skippedFocusSessionCount: 4,
            skippedBadgeCount: 5
        )

        let summary = preview.selectionSummary(selectedCandidateIDs: ["profile"])

        #expect(summary.profileCount == 1)
        #expect(summary.siteCount == 2)
        #expect(summary.appCount == 3)
        #expect(summary.scheduleCount == 1)
        #expect(summary.totalImportItemCount == 7)
        #expect(summary.skippedFocusSessionCount == 4)
        #expect(summary.skippedBadgeCount == 5)
        #expect(summary.sourceSummary == "FocusYouBackup-20260505/default.store")
        #expect(summary.importSummaryText.contains("총 7개"))
    }

    @Test("selection summary describes empty partial and full selections")
    func selectionSummaryDescribesEmptyPartialAndFullSelections() {
        let profile = DataStoreRecoveryImportProfileCandidate(
            id: "profile",
            displayName: "Deep Work",
            sourceName: "Deep Work",
            isOrphanLegacyBlocks: false,
            siteCount: 2,
            appCount: 3,
            scheduleCount: 1
        )
        let orphan = DataStoreRecoveryImportProfileCandidate(
            id: "orphan",
            displayName: "Imported Legacy Blocks",
            sourceName: nil,
            isOrphanLegacyBlocks: true,
            siteCount: 1,
            appCount: 0,
            scheduleCount: 2
        )
        let preview = DataStoreRecoveryImportPreview(
            inspectedAt: .distantPast,
            sourceDirectoryURL: URL(fileURLWithPath: "/tmp/FocusYouBackup-20260505"),
            sourceStoreFileName: "default.store",
            copiedStoreFiles: ["default.store", "default.store-wal"],
            profileCandidates: [profile, orphan],
            skippedFocusSessionCount: 4,
            skippedBadgeCount: 5
        )

        let empty = preview.selectionSummary(selectedCandidateIDs: [])
        let partial = preview.selectionSummary(selectedCandidateIDs: ["profile"])
        let full = preview.selectionSummary(selectedCandidateIDs: ["profile", "orphan"])

        #expect(empty.selectedCandidateCount == 0)
        #expect(empty.totalCandidateCount == 2)
        #expect(!empty.canImport)
        #expect(empty.selectionSummaryText == "선택된 항목이 없습니다.")

        #expect(partial.selectedCandidateCount == 1)
        #expect(partial.canImport)
        #expect(partial.selectionSummaryText == "프로필 2개 중 1개 선택")

        #expect(full.selectedCandidateCount == 2)
        #expect(full.totalImportItemCount == 11)
        #expect(full.selectionSummaryText == "프로필 2개 모두 선택")
    }
}
