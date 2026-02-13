import SwiftUI
import SwiftData

// MARK: - 카테고리 프리셋 선택 (v0.5 리디자인)

struct CategoryPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query private var sites: [BlockedSite]
    @Query private var apps: [BlockedApp]
    @State private var viewModel = BlockListViewModel()
    @State private var failedCategory: String?
    @State private var hoveredCategory: String?

    var body: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            Text("카테고리 프리셋을 선택하여 한 번에 추가하세요")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let failed = failedCategory {
                HStack(spacing: Constants.Design.spacingSM) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(themeManager.stopButton)
                    Text("'\(failed)' 프리셋을 불러올 수 없습니다")
                }
                .font(.caption)
                .foregroundStyle(themeManager.stopButton)
                .transition(.opacity)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140))],
                spacing: Constants.Design.spacingMD
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
        let isHovered = hoveredCategory == category

        return Button {
            withAnimation(.focusSpring) {
                if isApplied {
                    viewModel.removePreset(
                        category: category,
                        modelContext: modelContext
                    )
                    failedCategory = nil
                } else {
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
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: Constants.Design.spacingSM) {
                    IconBadge(
                        systemName: icon,
                        color: isApplied ? themeManager.completed : themeManager.primary,
                        size: 40
                    )

                    Text(category)
                        .font(.callout.weight(.semibold))

                    Text(isApplied ? "제거하기" : "추가하기")
                        .font(.caption)
                        .foregroundStyle(isApplied ? themeManager.stopButton : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Constants.Design.spacingLG)
                .background(
                    isApplied
                        ? themeManager.completed.opacity(0.06)
                        : Color.secondary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                        .stroke(
                            isApplied ? themeManager.completed.opacity(0.4) : Color.secondary.opacity(0.08),
                            lineWidth: isApplied ? 1.5 : 0.5
                        )
                )

                // 체크마크 오버레이
                if isApplied {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(themeManager.completed)
                        .background(Circle().fill(.background).padding(-2))
                        .offset(x: -8, y: 8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Constants.Design.cornerLG))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .shadow(
            color: isHovered ? themeManager.primary.opacity(0.1) : .clear,
            radius: 8, y: 2
        )
        .animation(.quickEase, value: isHovered)
        .onHover { hovering in
            hoveredCategory = hovering ? category : nil
        }
        .accessibilityLabel("\(category) 카테고리 프리셋, \(isApplied ? "적용됨" : "미적용")")
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
