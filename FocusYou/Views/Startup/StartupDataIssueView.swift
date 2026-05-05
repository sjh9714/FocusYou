import AppKit
import SwiftUI
import SwiftData

struct StartupDataIssueView: View {
    let issue: StartupDataIssue
    @Environment(\.modelContext) private var modelContext

    @State private var diagnostics: AppDataStoreDiagnosticsReport
    @State private var dataToolState = DataToolActionPresentationState()

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

                if let status = dataToolState.status {
                    Divider()
                        .padding(.vertical, 4)

                    Text("최근 작업")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    DataToolActionStatusView(status: status)
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
                        previewDataStoreBackup()
                    } label: {
                        Label("백업 미리보기", systemImage: "doc.text.magnifyingglass")
                    }

                    Button {
                        copyDiagnostics()
                    } label: {
                        Label("진단 정보 복사", systemImage: "doc.on.doc")
                    }
                }
                .disabled(dataToolState.isRunning)

                HStack {
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
                .disabled(dataToolState.isRunning)

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
        guard dataToolState.begin(.backup) else {
            return
        }

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
            dataToolState.cancel()
            return
        }

        do {
            let result = try DataStoreBackupService.createBackup(
                destinationDirectoryURL: destinationURL,
                diagnostics: diagnostics
            )
            dataToolState.succeed(
                .backup,
                message: "백업 완료: \(result.backupDirectoryURL.path)",
                destinationURL: result.backupDirectoryURL
            )
            NSWorkspace.shared.activateFileViewerSelecting([result.backupDirectoryURL])
        } catch {
            dataToolState.fail(.backup, message: "백업 실패: \(error.localizedDescription)")
        }
    }

    private func createSupportDiagnosticsBundle() {
        guard dataToolState.begin(.supportDiagnostics) else {
            return
        }

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
            dataToolState.cancel()
            return
        }

        do {
            let result = try SupportDiagnosticsBundleService.createBundle(
                destinationDirectoryURL: destinationURL,
                dataStoreDiagnostics: diagnostics,
                blockingSummary: .current(),
                redactionCandidates: redactionCandidates()
            )
            dataToolState.succeed(
                .supportDiagnostics,
                message: "진단 로그 완료: \(result.bundleDirectoryURL.path)",
                destinationURL: result.bundleDirectoryURL
            )
            NSWorkspace.shared.activateFileViewerSelecting([result.bundleDirectoryURL])
        } catch {
            dataToolState.fail(.supportDiagnostics, message: "진단 로그 실패: \(error.localizedDescription)")
        }
    }

    private func previewDataStoreBackup() {
        guard dataToolState.begin(.preview) else {
            return
        }

        let panel = NSOpenPanel()
        panel.title = "백업 폴더 선택"
        panel.prompt = "미리보기"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let backupURL = panel.url else {
            dataToolState.cancel()
            return
        }

        do {
            let preview = try DataStoreRecoveryPreviewService.previewBackup(at: backupURL)
            dataToolState.succeed(
                .preview,
                message: preview.statusSummary,
                destinationURL: backupURL
            )
        } catch {
            dataToolState.fail(.preview, message: "백업 미리보기 실패: \(error.localizedDescription)")
        }
    }

    private func copyDiagnostics() {
        guard dataToolState.begin(.copyDiagnostics) else {
            return
        }

        diagnostics = AppDataStoreDiagnostics.inspect(
            supportDirectoryURL: issue.supportDirectoryURL
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics.textSummary, forType: .string)
        dataToolState.succeed(
            .copyDiagnostics,
            message: "진단 정보를 클립보드에 복사했습니다."
        )
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
