import AppKit
import SwiftUI
import SwiftData

struct StartupDataIssueView: View {
    let issue: StartupDataIssue
    @Environment(\.modelContext) private var modelContext

    @State private var diagnostics: AppDataStoreDiagnosticsReport
    @State private var actionMessage: String?

    init(issue: StartupDataIssue) {
        self.issue = issue
        _diagnostics = State(
            initialValue: AppDataStoreDiagnostics.inspect(
                supportDirectoryURL: issue.supportDirectoryURL
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(issue.title, systemImage: "externaldrive.trianglebadge.exclamationmark")
                .font(.title3.bold())

            Text(issue.message)
                .foregroundStyle(.primary)

            Text(issue.recoverySuggestion)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("원래 오류")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(issue.originalErrorDescription)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("데이터 진단")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(diagnostics.statusSummary)
                    .font(.caption)
                    .foregroundStyle(diagnostics.isHealthy ? Color.secondary : Color.red)

                if let actionMessage {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button {
                        createBackup()
                    } label: {
                        Label("데이터 백업 만들기", systemImage: "archivebox")
                    }

                    Button {
                        copyDiagnostics()
                    } label: {
                        Label("진단 정보 복사", systemImage: "doc.on.doc")
                    }

                    Button {
                        openSupportDirectory()
                    } label: {
                        Label("Application Support 열기", systemImage: "folder")
                    }

                    Button {
                        createSupportDiagnosticsBundle()
                    } label: {
                        Label("진단 로그 내보내기", systemImage: "waveform.path.ecg")
                    }
                }

                HStack {
                    Spacer()

                    Button("앱 종료") {
                        NSApp.terminate(nil)
                    }

                    Button("앱 재시작") {
                        restartApp()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 360)
    }

    private func openSupportDirectory() {
        try? FileManager.default.createDirectory(
            at: issue.supportDirectoryURL,
            withIntermediateDirectories: true
        )
        NSWorkspace.shared.open(issue.supportDirectoryURL)
    }

    private func createBackup() {
        diagnostics = AppDataStoreDiagnostics.inspect(
            supportDirectoryURL: issue.supportDirectoryURL
        )

        let panel = NSOpenPanel()
        panel.title = "백업 저장 위치 선택"
        panel.prompt = "백업 만들기"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            let result = try DataStoreBackupService.createBackup(
                destinationDirectoryURL: destinationURL,
                diagnostics: diagnostics
            )
            actionMessage = "백업 완료: \(result.backupDirectoryURL.path)"
            NSWorkspace.shared.activateFileViewerSelecting([result.backupDirectoryURL])
        } catch {
            actionMessage = "백업 실패: \(error.localizedDescription)"
        }
    }

    private func createSupportDiagnosticsBundle() {
        diagnostics = AppDataStoreDiagnostics.inspect(
            supportDirectoryURL: issue.supportDirectoryURL
        )

        let panel = NSOpenPanel()
        panel.title = "진단 로그 저장 위치 선택"
        panel.prompt = "내보내기"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            let result = try SupportDiagnosticsBundleService.createBundle(
                destinationDirectoryURL: destinationURL,
                dataStoreDiagnostics: diagnostics,
                blockingSummary: .current(),
                redactionCandidates: redactionCandidates()
            )
            actionMessage = "진단 로그 완료: \(result.bundleDirectoryURL.path)"
            NSWorkspace.shared.activateFileViewerSelecting([result.bundleDirectoryURL])
        } catch {
            actionMessage = "진단 로그 실패: \(error.localizedDescription)"
        }
    }

    private func copyDiagnostics() {
        diagnostics = AppDataStoreDiagnostics.inspect(
            supportDirectoryURL: issue.supportDirectoryURL
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics.textSummary, forType: .string)
        actionMessage = "진단 정보를 클립보드에 복사했습니다."
    }

    private func restartApp() {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, _ in
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }

    private func redactionCandidates() -> [String] {
        var candidates: [String] = []

        if let profiles = try? modelContext.fetch(FetchDescriptor<BlockProfile>()) {
            candidates.append(contentsOf: profiles.map(\.name))
        }
        if let sites = try? modelContext.fetch(FetchDescriptor<BlockedSite>()) {
            candidates.append(contentsOf: sites.map(\.domain))
        }
        if let apps = try? modelContext.fetch(FetchDescriptor<BlockedApp>()) {
            candidates.append(contentsOf: apps.flatMap { [$0.name, $0.bundleId] })
        }

        return candidates
    }
}
