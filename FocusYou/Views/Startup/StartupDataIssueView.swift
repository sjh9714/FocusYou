import AppKit
import SwiftUI

struct StartupDataIssueView: View {
    let issue: StartupDataIssue

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

            Spacer(minLength: 0)

            HStack {
                Button {
                    openSupportDirectory()
                } label: {
                    Label("Application Support 열기", systemImage: "folder")
                }

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
        .padding(24)
        .frame(minWidth: 520, minHeight: 300)
    }

    private func openSupportDirectory() {
        try? FileManager.default.createDirectory(
            at: issue.supportDirectoryURL,
            withIntermediateDirectories: true
        )
        NSWorkspace.shared.open(issue.supportDirectoryURL)
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
}
