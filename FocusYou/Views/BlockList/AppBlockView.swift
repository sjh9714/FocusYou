import SwiftUI
import SwiftData

// MARK: - 앱 차단 관리

struct AppBlockView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var blockedApps: [BlockedApp]
    @State private var viewModel = BlockListViewModel()
    @State private var installedApps: [BlockListViewModel.InstalledApp] = []

    private var blockedBundleIds: Set<String> {
        Set(blockedApps.map(\.bundleId))
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("앱 검색...", text: $viewModel.appSearchText)
                .textFieldStyle(.roundedBorder)

            appList
        }
        .task {
            installedApps = viewModel.scanInstalledApps()
        }
    }

    // MARK: - 앱 목록

    private var filteredApps: [BlockListViewModel.InstalledApp] {
        if viewModel.appSearchText.isEmpty {
            return installedApps
        }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(viewModel.appSearchText)
        }
    }

    private var appList: some View {
        List(filteredApps) { app in
            appRow(app)
        }
        .listStyle(.inset)
    }

    private func appRow(_ app: BlockListViewModel.InstalledApp) -> some View {
        let isBlocked = blockedBundleIds.contains(app.bundleId)

        return HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 28, height: 28)

            Text(app.name)
                .font(.body)

            Spacer()

            Toggle("", isOn: Binding(
                get: { isBlocked },
                set: { newValue in
                    viewModel.toggleApp(
                        app,
                        isBlocked: newValue,
                        modelContext: modelContext
                    )
                }
            ))
            .labelsHidden()
        }
        .accessibilityLabel("\(app.name), \(isBlocked ? "차단 중" : "차단 안 함")")
    }
}

#Preview {
    AppBlockView()
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
}
