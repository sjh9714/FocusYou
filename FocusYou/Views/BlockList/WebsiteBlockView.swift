import SwiftUI
import SwiftData

// MARK: - 웹사이트 차단 관리

struct WebsiteBlockView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \BlockedSite.createdAt, order: .reverse)
    private var sites: [BlockedSite]
    @State private var viewModel = BlockListViewModel()

    var body: some View {
        VStack(spacing: 12) {
            inputField

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            siteList
        }
    }

    // MARK: - 입력 필드

    private var inputField: some View {
        HStack {
            TextField("example.com", text: $viewModel.newWebsiteURL)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("차단할 웹사이트 주소 입력")
                .onSubmit {
                    viewModel.addWebsite(modelContext: modelContext)
                }

            Button("추가") {
                viewModel.addWebsite(modelContext: modelContext)
            }
            .disabled(viewModel.newWebsiteURL.isEmpty)
        }
    }

    // MARK: - 사이트 목록

    private var siteList: some View {
        List {
            if sites.isEmpty {
                ContentUnavailableView(
                    "차단된 사이트 없음",
                    systemImage: "globe",
                    description: Text("위에서 차단할 사이트를 추가하세요")
                )
            } else {
                ForEach(sites) { site in
                    siteRow(site)
                }
                .onDelete { indexSet in
                    let toDelete = indexSet.map { sites[$0] }
                    viewModel.deleteSites(toDelete, modelContext: modelContext)
                }
            }
        }
        .listStyle(.inset)
    }

    private func siteRow(_ site: BlockedSite) -> some View {
        HStack(spacing: 10) {
            // 사이트 아이콘
            Image(systemName: "globe")
                .font(.system(size: 14))
                .foregroundStyle(site.isEnabled ? themeManager.primary : .secondary)
                .frame(width: 24, height: 24)

            // 도메인 + 카테고리
            VStack(alignment: .leading, spacing: 2) {
                Text(site.domain)
                    .font(.body)
                    .foregroundStyle(site.isEnabled ? .primary : .secondary)
                if let category = site.category {
                    Text(category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 삭제 버튼
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.deleteSites([site], modelContext: modelContext)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(site.domain) 삭제")

            // 활성/비활성 토글 (스위치)
            Toggle("", isOn: Bindable(site).isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    WebsiteBlockView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
}
