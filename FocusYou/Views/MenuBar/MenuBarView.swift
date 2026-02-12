import SwiftUI
import SwiftData

// MARK: - 메뉴바 팝오버 메인 뷰

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query(filter: #Predicate<BlockedSite> { $0.isEnabled })
    private var enabledSites: [BlockedSite]

    @Query(filter: #Predicate<BlockedApp> { $0.isEnabled })
    private var enabledApps: [BlockedApp]

    var body: some View {
        VStack(spacing: 16) {
            // 상단 헤더
            headerView

            Divider()

            // 상태별 메인 콘텐츠
            switch appState.focusState {
            case .idle:
                IdleContentView(
                    sites: enabledSites,
                    apps: enabledApps
                )
            case .focusing, .paused:
                FocusingContentView()
            case .completed:
                CompletedContentView()
            }

            Divider()

            // 하단 버튼
            footerView
        }
        .padding()
        .frame(width: Constants.UI.popoverWidth)
        .alert("오류", isPresented: Bindable(appState).showError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(appState.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
        }
    }

    // MARK: - 헤더

    private var headerView: some View {
        HStack {
            Image(systemName: "shield.fill")
                .foregroundStyle(ThemeManager.shared.primary)
            Text("Focus You")
                .font(.headline)
            Spacer()
            blockingSummary
        }
    }

    @ViewBuilder
    private var blockingSummary: some View {
        if appState.isBlockingActive {
            Text("차단 중")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(ThemeManager.shared.primary.opacity(0.2))
                .clipShape(Capsule())
        }
    }

    // MARK: - 푸터

    private var footerView: some View {
        HStack {
            Button {
                openWindow(id: "block-list")
            } label: {
                Label("차단 목록", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                openWindow(id: "settings")
            } label: {
                Label("설정", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

#Preview {
    MenuBarView()
        .environment(AppState())
        .environment(SettingsViewModel())
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
}
