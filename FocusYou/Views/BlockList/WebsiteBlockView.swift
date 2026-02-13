import SwiftUI
import SwiftData

// MARK: - 웹사이트 차단 관리 (v0.5 리디자인)

struct WebsiteBlockView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \BlockedSite.createdAt, order: .reverse)
    private var sites: [BlockedSite]
    @State private var viewModel = BlockListViewModel()
    @State private var hoveredSiteID: PersistentIdentifier?

    var body: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            inputField

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(themeManager.stopButton)
                    .transition(.opacity)
            }

            siteList
        }
    }

    // MARK: - 입력 필드

    private var inputField: some View {
        HStack(spacing: Constants.Design.spacingSM) {
            HStack(spacing: Constants.Design.spacingSM) {
                Image(systemName: "globe")
                    .font(.system(size: Constants.Design.iconSM))
                    .foregroundStyle(.tertiary)

                TextField("example.com (https:// 제외)", text: $viewModel.newWebsiteURL)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("차단할 웹사이트 주소 입력")
                    .onSubmit {
                        viewModel.addWebsite(modelContext: modelContext)
                    }
            }
            .padding(.horizontal, Constants.Design.spacingMD)
            .padding(.vertical, Constants.Design.spacingSM)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Constants.Design.cornerMD))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
            )

            Button {
                viewModel.addWebsite(modelContext: modelContext)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(themeManager.primary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.newWebsiteURL.isEmpty)
            .accessibilityLabel("사이트 추가")
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
        let isHovered = hoveredSiteID == site.persistentModelID

        return HStack(spacing: Constants.Design.spacingMD) {
            // 아이콘
            IconBadge(
                systemName: "globe",
                color: site.isEnabled ? themeManager.primary : .secondary,
                size: 28
            )

            // 도메인 + 카테고리
            VStack(alignment: .leading, spacing: 2) {
                Text(site.domain)
                    .font(.body)
                    .foregroundStyle(site.isEnabled ? .primary : .secondary)
                if let category = site.category {
                    Text(category)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // 삭제 버튼 (호버 시 표시)
            if isHovered {
                Button {
                    withAnimation(.quickEase) {
                        viewModel.deleteSites([site], modelContext: modelContext)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .accessibilityLabel("\(site.domain) 삭제")
            }

            // 토글
            Toggle("", isOn: Bindable(site).isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(themeManager.primary)
        }
        .padding(.vertical, Constants.Design.spacingXS)
        .onHover { hovering in
            withAnimation(.quickEase) {
                hoveredSiteID = hovering ? site.persistentModelID : nil
            }
        }
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
