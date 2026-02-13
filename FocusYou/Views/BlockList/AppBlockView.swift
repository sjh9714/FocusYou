import SwiftUI
import SwiftData

// MARK: - 앱 차단 관리 (v0.5 리디자인)

struct AppBlockView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query private var blockedApps: [BlockedApp]
    @State private var viewModel = BlockListViewModel()
    @State private var installedApps: [BlockListViewModel.InstalledApp] = []
    @State private var isLoading = true

    private var blockedBundleIds: Set<String> {
        Set(blockedApps.map(\.bundleId))
    }

    var body: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            searchField
            appContent
        }
        .task {
            installedApps = viewModel.scanInstalledApps()
            isLoading = false
        }
    }

    // MARK: - 검색 필드

    private var searchField: some View {
        HStack(spacing: Constants.Design.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Constants.Design.iconSM))
                .foregroundStyle(.tertiary)

            TextField("앱 검색...", text: $viewModel.appSearchText)
                .textFieldStyle(.plain)
                .accessibilityLabel("설치된 앱 검색")
        }
        .padding(.horizontal, Constants.Design.spacingMD)
        .padding(.vertical, Constants.Design.spacingSM)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Constants.Design.cornerMD))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - 앱 콘텐츠

    @ViewBuilder
    private var appContent: some View {
        if isLoading {
            loadingSkeleton
        } else if filteredApps.isEmpty {
            ContentUnavailableView(
                viewModel.appSearchText.isEmpty ? "설치된 앱 없음" : "검색 결과 없음",
                systemImage: "app.dashed",
                description: Text(viewModel.appSearchText.isEmpty
                    ? "차단할 수 있는 앱이 없습니다"
                    : "'\(viewModel.appSearchText)' 검색 결과가 없습니다")
            )
        } else {
            appList
        }
    }

    // MARK: - 스켈레톤 로딩

    private var loadingSkeleton: some View {
        VStack(spacing: Constants.Design.spacingSM) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: Constants.Design.spacingMD) {
                    RoundedRectangle(cornerRadius: Constants.Design.cornerSM)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 32, height: 32)

                    RoundedRectangle(cornerRadius: Constants.Design.cornerSM)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(width: 120, height: 14)

                    Spacer()
                }
                .padding(.vertical, Constants.Design.spacingSM)
            }
            .shimmering()
        }
        .frame(maxHeight: .infinity, alignment: .top)
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

        return HStack(spacing: Constants.Design.spacingMD) {
            // 차단된 앱: 좌측 프라이머리 보더
            Rectangle()
                .fill(isBlocked ? themeManager.primary : Color.clear)
                .frame(width: 3)
                .clipShape(Capsule())

            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .opacity(isBlocked ? 1.0 : 0.5)

            Text(app.name)
                .font(.body)
                .foregroundStyle(isBlocked ? .primary : .secondary)

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
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(themeManager.primary)
        }
        .frame(height: 44)
        .accessibilityLabel("\(app.name), \(isBlocked ? "차단 중" : "차단 안 함")")
    }
}

// MARK: - 쉬머링 애니메이션

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Color.primary.opacity(0.15),
                        .clear,
                    ],
                    startPoint: .init(x: phase - 0.5, y: 0.5),
                    endPoint: .init(x: phase + 0.5, y: 0.5)
                )
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

#Preview {
    AppBlockView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
}
