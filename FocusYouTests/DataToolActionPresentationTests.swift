import Foundation
import Testing
@testable import Focus_You

@Suite("DataToolActionPresentation")
struct DataToolActionPresentationTests {
    @Test("begin replaces stale result with running status")
    func beginReplacesStaleResultWithRunningStatus() {
        var state = DataToolActionPresentationState()
        let backupURL = URL(fileURLWithPath: "/tmp/FocusYouBackup")

        state.succeed(
            .backup,
            message: "백업 완료",
            destinationURL: backupURL
        )

        #expect(state.status?.phase == .success)
        #expect(state.status?.destinationURL == backupURL)

        let didBegin = state.begin(.supportDiagnostics)

        #expect(didBegin)
        #expect(state.isRunning)
        #expect(state.status?.action == .supportDiagnostics)
        #expect(state.status?.phase == .running)
        #expect(state.status?.destinationURL == nil)
    }

    @Test("duplicate begin is blocked while preserving running status")
    func duplicateBeginIsBlockedWhilePreservingRunningStatus() {
        var state = DataToolActionPresentationState()

        let firstBegin = state.begin(.backup)
        let duplicateBegin = state.begin(.preview)

        #expect(firstBegin)
        #expect(!duplicateBegin)
        #expect(state.isRunning)
        #expect(state.status?.action == .backup)
        #expect(state.status?.phase == .running)
    }

    @Test("success and failure expose destination action availability")
    func successAndFailureExposeDestinationActionAvailability() {
        let backupURL = URL(fileURLWithPath: "/tmp/FocusYouBackup")
        let success = DataToolActionStatus.success(
            .backup,
            message: "백업 완료",
            destinationURL: backupURL
        )
        let failure = DataToolActionStatus.failure(
            .backup,
            message: "백업 실패"
        )

        #expect(success.canOpenDestination)
        #expect(success.destinationPath == backupURL.path)
        #expect(!failure.canOpenDestination)
        #expect(failure.destinationPath == nil)
    }
}
