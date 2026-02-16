import SwiftUI
import SwiftData

// MARK: - 메뉴바 팝오버 메인 뷰 (v0.5 리디자인)

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.openWindow) private var openWindow

    @Query(
        filter: #Predicate<FocusSession> { $0.wasCompleted },
        sort: \FocusSession.startedAt,
        order: .reverse
    )
    private var sessions: [FocusSession]

    /// 앱 시작 시 대시보드를 1회만 자동 열기 위한 플래그
    private static var hasAutoOpenedDashboard = false

    var body: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            headerView

            if appState.showError {
                inlineErrorPanel
            }

            if appState.showPrivateRelayWarning {
                privateRelayWarningPanel
            }

            Rectangle().fill(.quaternary).frame(height: 0.5)

            Group {
                switch appState.focusState {
                case .idle:
                    IdleContentView()
                case .focusing, .paused:
                    FocusingContentView()
                case .completed:
                    CompletedContentView()
                }
            }
            .animation(.mediumEase, value: appState.focusState)

            Rectangle().fill(.quaternary).frame(height: 0.5)

            footerView
        }
        .padding()
        .frame(width: Constants.UI.popoverWidth)
        .animation(.quickEase, value: appState.showError)
        .animation(.quickEase, value: appState.showPrivateRelayWarning)
        .task {
            guard !Self.hasAutoOpenedDashboard else { return }
            Self.hasAutoOpenedDashboard = true
            try? await Task.sleep(for: .milliseconds(300))
            openWindow(id: "main-dashboard")
        }
    }

    // MARK: - 헤더

    private var headerView: some View {
        HStack(spacing: Constants.Design.spacingSM) {
            // 그라디언트 쉴드 아이콘
            Image(systemName: "shield.fill")
                .font(.system(size: 16))
                .foregroundStyle(themeManager.primary)
                .frame(width: 28, height: 28)
                .background(
                    themeManager.primary.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: Constants.Design.cornerSM)
                )

            Text("Focus You")
                .font(.headline)

            growthIndicator

            Spacer()

            if appState.isBlockingActive {
                blockingBadge
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus You\(appState.isBlockingActive ? ", 차단 활성화 상태" : "")")
    }

    private var growthIndicator: some View {
        let totalHours = Double(sessions.reduce(0) { $0 + $1.actualDuration }) / 3600.0
        let stage = GrowthManager.currentStage(totalHours: totalHours)
        return Text(stage.emoji)
            .font(.caption)
            .help(String(localized: "\(stage.name) — \(Int(totalHours))시간 누적"))
    }

    private var blockingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .symbolEffect(.pulse, options: .repeating, isActive: true)

            Text("차단 중")
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(themeManager.primary.opacity(0.1))
        .foregroundStyle(themeManager.primary)
        .clipShape(Capsule())
    }

    // MARK: - 에러 패널

    private var inlineErrorPanel: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Label("오류", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(themeManager.stopButton)

            Text(appState.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: Constants.Design.spacingSM) {
                if appState.canRetryBlockingDeactivation {
                    Button {
                        Task {
                            await appState.retryBlockingDeactivation()
                        }
                    } label: {
                        Text("다시 시도")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionStyle(color: themeManager.stopButton)
                }

                Button {
                    appState.dismissError()
                } label: {
                    Text("닫기")
                        .frame(maxWidth: .infinity)
                }
                .secondaryActionStyle(color: .secondary)
            }
        }
        .frostedCard()
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                .stroke(themeManager.stopButton.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Private Relay 경고 패널

    private var privateRelayWarningPanel: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Label(
                "Private Relay가 Safari 차단을 우회 중",
                systemImage: "exclamationmark.shield.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(themeManager.warning)

            Text("iCloud Private Relay가 켜져 있어 Safari에서 웹사이트 차단이 우회됩니다. 아래 방법 중 하나를 선택하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                // 1. 정보성 — 다른 브라우저 안내
                Label {
                    Text("Chrome, Firefox 등에서는 정상 차단됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                }

                // 2. Private Relay 설정 열기
                Button {
                    appState.openPrivateRelaySettings()
                } label: {
                    Label("Private Relay 설정 열기", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .primaryActionStyle(color: themeManager.warning)
            }

            Button {
                appState.dismissPrivateRelayWarning()
            } label: {
                Text("닫기")
                    .frame(maxWidth: .infinity)
            }
            .secondaryActionStyle(color: .secondary)
        }
        .frostedCard()
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                .stroke(themeManager.warning.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - 푸터

    private var footerView: some View {
        HStack(spacing: 0) {
            footerButton(title: "차단 목록", symbol: "list.bullet.rectangle") {
                openWindow(id: "block-list")
                NSApp.activate(ignoringOtherApps: true)
            }

            Spacer()

            footerButton(title: "대시보드", symbol: "square.grid.2x2") {
                openWindow(id: "main-dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }

            Spacer()

            footerButton(title: "설정", symbol: "gearshape") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func footerButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .frame(width: 36, height: 28)
                Text(LocalizedStringKey(title))
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(title)))
    }
}

#Preview {
    MenuBarView()
        .environment(AppState())
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .environment(LicenseManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
}
