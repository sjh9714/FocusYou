import SwiftUI

// MARK: - 차단 목록 관리 (v0.5 리디자인)

struct BlockListView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var selectedTab: Tab = .websites
    @Namespace private var tabNamespace

    enum Tab: String, CaseIterable, Hashable {
        case websites
        case apps
        case categories

        var title: String {
            switch self {
            case .websites: return "웹사이트"
            case .apps: return "앱"
            case .categories: return "카테고리"
            }
        }

        var icon: String {
            switch self {
            case .websites: return "globe"
            case .apps: return "app.fill"
            case .categories: return "folder.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 커스텀 세그먼트 바
            tabBar

            Rectangle().fill(.quaternary).frame(height: 0.5)

            // 탭 콘텐츠
            Group {
                switch selectedTab {
                case .websites:
                    WebsiteBlockView()
                case .apps:
                    AppBlockView()
                case .categories:
                    CategoryPickerView()
                }
            }
            .padding()
            .animation(.mediumEase, value: selectedTab)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                SegmentedPill(
                    title: tab.title,
                    tag: tab,
                    selection: $selectedTab,
                    namespace: tabNamespace,
                    activeColor: themeManager.primary
                )
            }
        }
        .padding(4)
        .background(Color.secondary.opacity(0.06), in: Capsule())
        .padding(.horizontal)
        .padding(.vertical, Constants.Design.spacingMD)
    }
}

#Preview {
    BlockListView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
}
