import SwiftUI
import SwiftData

// MARK: - 웹사이트 차단 관리

struct WebsiteBlockView: View {
    @Environment(\.modelContext) private var modelContext
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
        HStack {
            Toggle(isOn: Bindable(site).isEnabled) {
                VStack(alignment: .leading) {
                    Text(site.domain)
                        .font(.body)
                    if let category = site.category {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    WebsiteBlockView()
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
}
