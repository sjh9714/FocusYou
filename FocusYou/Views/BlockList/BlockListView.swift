import SwiftUI

// MARK: - 차단 목록 관리 (별도 윈도우)

struct BlockListView: View {
    @State private var selectedTab: Tab = .websites

    enum Tab: Hashable {
        case websites
        case apps
        case categories
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WebsiteBlockView()
                .tabItem {
                    Label("웹사이트", systemImage: "globe")
                }
                .tag(Tab.websites)

            AppBlockView()
                .tabItem {
                    Label("앱", systemImage: "app.fill")
                }
                .tag(Tab.apps)

            CategoryPickerView()
                .tabItem {
                    Label("카테고리", systemImage: "folder.fill")
                }
                .tag(Tab.categories)
        }
        .padding()
    }
}

#Preview {
    BlockListView()
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
}
