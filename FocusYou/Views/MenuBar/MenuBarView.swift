import SwiftUI
import SwiftData

// MARK: - 메뉴바 팝오버 메인 뷰 (v0.5 리디자인)

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<FocusSession> { $0.wasCompleted },
        sort: \FocusSession.startedAt,
        order: .reverse
    )
    private var sessions: [FocusSession]

    /// 대시보드 자동 열기 플래그는 AppDelegate에서 관리 (씬 리빌드 시에도 유지)

    var body: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            headerView

            if appState.showError {
                ErrorPanelView(bodyFont: .caption)
            }

            if appState.showPrivateRelayWarning {
                PrivateRelayWarningPanel(bodyFont: .caption)
            }

            if let scheduleName = appState.activeScheduleName {
                activeScheduleBanner(scheduleName)
            }

            if let rejoinInfo = appState.pendingScheduleRejoin,
               appState.focusState == .idle {
                scheduleRejoinBanner(rejoinInfo)
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

    // MARK: - 활성 스케줄 배너

    private func activeScheduleBanner(_ name: String) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            Image(systemName: "calendar.badge.clock")
                .font(.caption)
                .foregroundStyle(themeManager.primary)

            Text("스케줄: \(name)")
                .font(.caption.weight(.medium))
                .foregroundStyle(themeManager.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(themeManager.primary.opacity(0.08), in: Capsule())
    }

    // MARK: - 스케줄 재참여 배너

    private func scheduleRejoinBanner(_ info: AppState.PendingScheduleInfo) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            Image(systemName: "calendar.badge.clock")
                .font(.caption)
                .foregroundStyle(themeManager.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(info.scheduleName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("\(info.endTimeFormatted)까지 진행 중")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await appState.rejoinPendingSchedule(
                        modelContext: modelContext
                    )
                }
            } label: {
                Text("참여하기")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(themeManager.accent, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(Constants.Design.spacingSM)
        .background(themeManager.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerMD))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                .stroke(themeManager.accent.opacity(0.15), lineWidth: 0.5)
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
