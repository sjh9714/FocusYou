import SwiftUI
import SwiftData

// MARK: - 카테고리 프리셋 선택

struct CategoryPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query private var sites: [BlockedSite]
    @Query private var apps: [BlockedApp]
    @State private var viewModel = BlockListViewModel()
    @State private var failedCategory: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("카테고리 프리셋을 선택하여 한 번에 추가하세요")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let failed = failedCategory {
                Text("'\(failed)' 프리셋을 불러올 수 없습니다")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140))],
                spacing: 12
            ) {
                ForEach(Constants.Category.all, id: \.self) { category in
                    categoryCard(category)
                }
            }

            Spacer()
        }
    }

    private func categoryCard(_ category: String) -> some View {
        let isApplied = appliedCategories.contains(category)
        let icon = Constants.Category.icons[category] ?? "folder.fill"

        return Button {
            if isApplied {
                // 토글: 제거
                viewModel.removePreset(
                    category: category,
                    modelContext: modelContext
                )
                failedCategory = nil
            } else {
                // 토글: 추가
                if viewModel.loadPreset(category: category) != nil {
                    viewModel.applyPreset(
                        category: category,
                        modelContext: modelContext
                    )
                    failedCategory = nil
                } else {
                    failedCategory = category
                }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)

                Text(category)
                    .font(.callout.bold())

                if isApplied {
                    Text("제거하기")
                        .font(.caption)
                        .foregroundStyle(themeManager.stopButton)
                } else {
                    Text("추가하기")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isApplied
                    ? themeManager.completed.opacity(0.1)
                    : Color.secondary.opacity(0.08)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isApplied
                            ? themeManager.completed
                            : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category) 카테고리 프리셋")
    }

    private var appliedCategories: Set<String> {
        let modelCategories = Set(
            sites.compactMap(\.category) + apps.compactMap(\.category)
        )
        return Set(Constants.Category.all.filter { modelCategories.contains($0) })
    }
}

#Preview {
    CategoryPickerView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
        .frame(width: 400)
        .padding()
}
