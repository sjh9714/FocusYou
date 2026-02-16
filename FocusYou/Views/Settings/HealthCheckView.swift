import SwiftUI
import os

// MARK: - 차단 상태 진단 (v1.3)

struct HealthCheckView: View {
    @Environment(ThemeManager.self) private var themeManager

    @State private var privateRelayStatus: PrivateRelayDetector.Status?
    @State private var hostsBlockingActive = false
    @State private var isDiagnosing = false
    @State private var dnsFlushResult: String?

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
