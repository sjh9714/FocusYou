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

        let summary = preview.selectionSummary(
            selection: DataStoreRecoveryImportSelection(selectedCandidateIDs: ["profile"])
        )

        #expect(summary.profileCount == 1)
        #expect(summary.siteCount == 2)
        #expect(summary.appCount == 3)
        #expect(summary.scheduleCount == 1)
        #expect(summary.totalImportItemCount == 7)
        #expect(summary.importedFocusSessionCount == 0)
        #expect(summary.importedBadgeCount == 0)
        #expect(summary.skippedFocusSessionCount == 4)
        #expect(summary.skippedBadgeCount == 5)
        #expect(summary.skippedSummaryText == "세션 4개와 배지 5개는 가져오지 않습니다.")
        #expect(summary.sourceSummary == "FocusYouBackup-20260505/default.store")
        #expect(summary.importSummaryText.contains("총 7개"))
    }

    @Test("selection summary includes optional sessions and badges only when selected")
    func selectionSummaryIncludesOptionalSessionsAndBadgesOnlyWhenSelected() {
        let profile = DataStoreRecoveryImportProfileCandidate(
            id: "profile",
            displayName: "Deep Work",
            sourceName: "Deep Work",
            isOrphanLegacyBlocks: false,
            siteCount: 2,
            appCount: 3,
            scheduleCount: 1
        )
        let preview = DataStoreRecoveryImportPreview(
            inspectedAt: .distantPast,
            sourceDirectoryURL: URL(fileURLWithPath: "/tmp/FocusYouBackup-20260505"),
            sourceStoreFileName: "default.store",
            copiedStoreFiles: ["default.store"],
            profileCandidates: [profile],
            skippedFocusSessionCount: 4,
            skippedBadgeCount: 5
        )

        let summary = preview.selectionSummary(
            selection: DataStoreRecoveryImportSelection(
                selectedCandidateIDs: ["profile"],
                includeFocusSessions: true,
                includeBadges: true
            )
        )

        #expect(summary.importedFocusSessionCount == 4)
        #expect(summary.importedBadgeCount == 5)
        #expect(summary.skippedFocusSessionCount == 0)
        #expect(summary.skippedBadgeCount == 0)
        #expect(summary.totalImportItemCount == 16)
        #expect(summary.importSummaryText.contains("세션 4개"))
        #expect(summary.importSummaryText.contains("배지 5개"))
        #expect(summary.skippedSummaryText == "세션 새 항목 4개와 배지 새 항목 5개를 가져옵니다. 중복 항목은 없습니다.")
        #expect(summary.focusSessionOptionText == "새 세션 4개를 추가합니다. 중복 항목은 없습니다.")
        #expect(summary.badgeOptionText == "새 배지 5개를 추가합니다. 중복 항목은 없습니다.")
    }

    @Test("selection summary reflects target-aware duplicate history counts")
    func selectionSummaryReflectsTargetAwareDuplicateHistoryCounts() {
        let profile = DataStoreRecoveryImportProfileCandidate(
            id: "profile",
            displayName: "Deep Work",
            sourceName: "Deep Work",
            isOrphanLegacyBlocks: false,
            siteCount: 1,
            appCount: 1,
            scheduleCount: 1
        )
        let preview = DataStoreRecoveryImportPreview(
            inspectedAt: .distantPast,
            sourceDirectoryURL: URL(fileURLWithPath: "/tmp/FocusYouBackup-20260505"),
            sourceStoreFileName: "default.store",
            copiedStoreFiles: ["default.store"],
            profileCandidates: [profile],
            skippedFocusSessionCount: 4,
            skippedBadgeCount: 5,
            duplicateFocusSessionCount: 2,
            duplicateBadgeCount: 1
        )

        let summary = preview.selectionSummary(
            selection: DataStoreRecoveryImportSelection(
                selectedCandidateIDs: ["profile"],
                includeFocusSessions: true,
                includeBadges: true
            )
        )

        #expect(preview.importableFocusSessionCount == 2)
        #expect(preview.importableBadgeCount == 4)
        #expect(summary.importedFocusSessionCount == 2)
        #expect(summary.importedBadgeCount == 4)
        #expect(summary.skippedFocusSessionCount == 2)
        #expect(summary.skippedBadgeCount == 1)
        #expect(summary.skippedSummaryText == "세션 새 항목 2개와 배지 새 항목 4개를 가져옵니다. 중복 세션 2개와 중복 배지 1개는 건너뜁니다.")
        #expect(summary.focusSessionOptionText == "새 세션 2개를 추가합니다. 중복 세션 2개는 건너뜁니다.")
        #expect(summary.badgeOptionText == "새 배지 4개를 추가합니다. 중복 배지 1개는 건너뜁니다.")
        #expect(summary.confirmationMessageText.contains("세션 새 항목 2개"))
        #expect(summary.confirmationMessageText.contains("배지 새 항목 4개"))
    }

    @Test("selection summary describes zero new history items when all are duplicates")
    func selectionSummaryDescribesZeroNewHistoryItemsWhenAllAreDuplicates() {
        let profile = DataStoreRecoveryImportProfileCandidate(
            id: "profile",
            displayName: "Deep Work",
            sourceName: "Deep Work",
            isOrphanLegacyBlocks: false,
            siteCount: 0,
            appCount: 0,
            scheduleCount: 0
        )
        let preview = DataStoreRecoveryImportPreview(
            inspectedAt: .distantPast,
            sourceDirectoryURL: URL(fileURLWithPath: "/tmp/FocusYouBackup-20260505"),
            sourceStoreFileName: "default.store",
            copiedStoreFiles: ["default.store"],
            profileCandidates: [profile],
            skippedFocusSessionCount: 1,
            skippedBadgeCount: 2,
            duplicateFocusSessionCount: 1,
            duplicateBadgeCount: 2
        )

        let summary = preview.selectionSummary(
            selection: DataStoreRecoveryImportSelection(
                selectedCandidateIDs: ["profile"],
                includeFocusSessions: true,
                includeBadges: true
            )
        )

        #expect(summary.importedFocusSessionCount == 0)
        #expect(summary.importedBadgeCount == 0)
        #expect(summary.totalImportItemCount == 1)
        #expect(summary.skippedSummaryText == "세션 새 항목 0개와 배지 새 항목 0개를 가져옵니다. 중복 세션 1개와 중복 배지 2개는 건너뜁니다.")
        #expect(summary.focusSessionOptionText == "새 세션 0개를 추가합니다. 중복 세션 1개는 건너뜁니다.")
        #expect(summary.badgeOptionText == "새 배지 0개를 추가합니다. 중복 배지 2개는 건너뜁니다.")
        #expect(summary.confirmationMessageText.contains("세션 새 항목 0개"))
        #expect(summary.confirmationMessageText.contains("배지 새 항목 0개"))
        #expect(summary.confirmationMessageText.contains("중복 세션 1개"))
        #expect(summary.confirmationMessageText.contains("중복 배지 2개"))
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

        let empty = preview.selectionSummary(
            selection: DataStoreRecoveryImportSelection(selectedCandidateIDs: [])
        )
        let partial = preview.selectionSummary(
            selection: DataStoreRecoveryImportSelection(selectedCandidateIDs: ["profile"])
        )
        let full = preview.selectionSummary(
            selection: DataStoreRecoveryImportSelection(selectedCandidateIDs: ["profile", "orphan"])
        )

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
