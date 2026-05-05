import SwiftUI
import AppKit
import SwiftData
import os

// MARK: - 차단 상태 진단 (v1.3)

struct HealthCheckView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext

    @State private var privateRelayStatus: PrivateRelayDetector.Status?
    @State private var hostsBlockingActive = false
    @State private var dataStoreDiagnostics: AppDataStoreDiagnosticsReport?
    @State private var isDiagnosing = false
    @State private var dnsFlushResult: String?
    @State private var dataToolState = DataToolActionPresentationState()
    @State private var selectedImportBackupURL: URL?
    @State private var dataStoreImportPreview: DataStoreRecoveryImportPreview?
    @State private var selectedImportCandidateIDs: Set<String> = []
    @State private var isImportPreviewPresented = false

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "HealthCheck"
    )

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingLG) {
            Text("차단 상태 진단")
                .font(.headline)

            VStack(spacing: Constants.Design.spacingMD) {
                privateRelayRow
                hostsBlockingRow
                dataStoreRow
                dnsFlushRow
            }

            if isDiagnosing {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding()
        .task {
            await runDiagnostics()
        }
        .sheet(isPresented: $isImportPreviewPresented) {
            if let dataStoreImportPreview {
                DataStoreRecoveryImportPreviewSheet(
                    preview: dataStoreImportPreview,
                    selectedCandidateIDs: $selectedImportCandidateIDs,
                    isImporting: dataToolState.status?.action == .importSettings && dataToolState.isRunning,
                    onCancel: clearImportPreview,
                    onImport: importSelectedBackupCandidates
                )
            }
        }
    }

    // MARK: - Safari Private Relay

    private var privateRelayRow: some View {
        HStack(spacing: Constants.Design.spacingMD) {
            diagnosticIcon(
                status: privateRelayStatus == .disabled || privateRelayStatus == .unknown
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("Safari Private Relay")
                    .font(.callout.weight(.medium))

                switch privateRelayStatus {
                case .enabled:
                    Text("활성화됨 — hosts 차단이 우회될 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(themeManager.stopButton)
                case .disabled:
                    Text("비활성화됨 — 정상")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .unknown:
                    Text("확인 불가")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case nil:
                    Text("진단 중...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if privateRelayStatus == .enabled {
                Button("설정 열기") {
                    if let url = URL(
                        string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane"
                    ) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(themeManager.primary)
            }
        }
        .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
    }

    // MARK: - hosts 파일 차단

    private var hostsBlockingRow: some View {
        HStack(spacing: Constants.Design.spacingMD) {
            diagnosticIcon(status: true)

            VStack(alignment: .leading, spacing: 2) {
                Text("hosts 파일 차단")
                    .font(.callout.weight(.medium))

                Text(LocalizedStringKey(hostsBlockingActive ? "활성 차단 중" : "비활성 (정상 대기)"))
                    .font(.caption)
                    .foregroundStyle(hostsBlockingActive ? themeManager.primary : .secondary)
            }

            Spacer()
        }
        .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
    }

    // MARK: - 데이터 저장소

    private var dataStoreRow: some View {
        HStack(spacing: Constants.Design.spacingMD) {
            diagnosticIcon(status: dataStoreDiagnostics?.isHealthy ?? true)

            VStack(alignment: .leading, spacing: 2) {
                Text("데이터 저장소")
                    .font(.callout.weight(.medium))

                Text(dataStoreDiagnostics?.statusSummary ?? "진단 중...")
                    .font(.caption)
                    .foregroundStyle(dataStoreDiagnostics?.isHealthy == false ? themeManager.stopButton : Color.secondary)

                if let status = dataToolState.status {
                    Divider()
                        .padding(.vertical, 4)

                    Text("최근 작업")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    DataToolActionStatusView(status: status)
                }
            }

            Spacer()

            Menu {
                Button {
                    createDataStoreBackup()
                } label: {
                    Label("백업 만들기", systemImage: "archivebox")
                }

                Button {
                    previewDataStoreBackup()
                } label: {
                    Label("백업 미리보기", systemImage: "doc.text.magnifyingglass")
                }

                Button {
                    chooseBackupForImport()
                } label: {
                    Label("백업 가져오기", systemImage: "tray.and.arrow.down")
                }

                Divider()

                Button {
                    createSupportDiagnosticsBundle()
                } label: {
                    Label("진단 로그 내보내기", systemImage: "waveform.path.ecg")
                }
            } label: {
                Label("데이터 도구", systemImage: "externaldrive")
            }
            .disabled(dataToolState.isRunning)
            .font(.caption)
            .foregroundStyle(themeManager.primary)
        }
        .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
    }

    // MARK: - DNS 캐시 플러시

    private var dnsFlushRow: some View {
        HStack(spacing: Constants.Design.spacingMD) {
            IconBadge(
                systemName: "arrow.triangle.2.circlepath",
                color: themeManager.accent,
                size: 28
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("DNS 캐시")
                    .font(.callout.weight(.medium))

                if let result = dnsFlushResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("차단이 적용되지 않을 때 플러시하세요.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button("DNS 플러시") {
                Task { await flushDNS() }
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.primary)
        }
        .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
    }

    // MARK: - 진단 실행

    private func runDiagnostics() async {
        isDiagnosing = true

        privateRelayStatus = PrivateRelayDetector.detect()
        hostsBlockingActive = await HostsFileManager.shared.hasActiveBlocking()
        dataStoreDiagnostics = AppDataStoreDiagnostics.inspect()

        isDiagnosing = false
    }

    private func flushDNS() async {
        do {
            try await DNSManager.shared.flushDNSCache()
            dnsFlushResult = String(localized: "DNS 캐시 플러시 완료")
        } catch {
            dnsFlushResult = String(localized: "플러시 실패: \(error.localizedDescription)")
        }
    }

    private func createDataStoreBackup() {
        guard dataToolState.begin(.backup) else {
            return
        }

        let diagnostics = AppDataStoreDiagnostics.inspect()
        dataStoreDiagnostics = diagnostics

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

    private func chooseBackupForImport() {
        guard dataToolState.begin(.importSettings) else {
            return
        }

        let panel = NSOpenPanel()
        panel.title = "가져올 백업 폴더 선택"
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
            let preview = try DataStoreRecoveryImportService.previewImport(at: backupURL)
            guard !preview.profileCandidates.isEmpty else {
                dataToolState.fail(.importSettings, message: "가져올 설정 데이터가 없습니다.")
                return
            }

            selectedImportBackupURL = backupURL
            dataStoreImportPreview = preview
            selectedImportCandidateIDs = Set(preview.profileCandidates.map { $0.id })
            dataToolState.cancel()
            isImportPreviewPresented = true
        } catch {
            dataToolState.fail(.importSettings, message: "백업 가져오기 실패: \(error.localizedDescription)")
        }
    }

    private func importSelectedBackupCandidates() {
        guard dataToolState.begin(.importSettings) else {
            return
        }

        guard let selectedImportBackupURL else {
            dataToolState.fail(.importSettings, message: "백업 가져오기 실패: 백업 폴더를 찾을 수 없습니다.")
            clearImportPreview()
            return
        }

        do {
            let result = try DataStoreRecoveryImportService.importSelectedCandidates(
                from: selectedImportBackupURL,
                selectedCandidateIDs: selectedImportCandidateIDs,
                into: modelContext
            )
            dataToolState.succeed(
                .importSettings,
                message: result.statusSummary,
                destinationURL: selectedImportBackupURL
            )
            dataStoreDiagnostics = AppDataStoreDiagnostics.inspect()
        } catch {
            dataToolState.fail(.importSettings, message: "백업 가져오기 실패: \(error.localizedDescription)")
        }

        clearImportPreview()
    }

    private func clearImportPreview() {
        isImportPreviewPresented = false
        dataStoreImportPreview = nil
        selectedImportBackupURL = nil
        selectedImportCandidateIDs = []
    }

    private func createSupportDiagnosticsBundle() {
        guard dataToolState.begin(.supportDiagnostics) else {
            return
        }

        let diagnostics = AppDataStoreDiagnostics.inspect()
        dataStoreDiagnostics = diagnostics

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
                blockingSummary: SupportDiagnosticsBlockingSummary.current(
                    hostsBlockingActive: hostsBlockingActive,
                    privateRelayStatus: privateRelayStatus
                ),
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

    private func diagnosticIcon(status: Bool) -> some View {
        IconBadge(
            systemName: status ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
            color: status ? themeManager.success : themeManager.stopButton,
            size: 28
        )
    }
}

#Preview {
    HealthCheckView()
        .environment(ThemeManager.shared)
        .frame(width: 400)
}
