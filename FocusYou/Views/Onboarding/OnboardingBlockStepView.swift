import SwiftUI
import SwiftData

// MARK: - 온보딩 Step 2: 차단 카테고리 선택 (v1.0)

struct OnboardingBlockStepView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BlockProfile.createdAt)
    private var profiles: [BlockProfile]
    @Query private var sites: [BlockedSite]
    @Query private var apps: [BlockedApp]

    @State private var viewModel = BlockListViewModel()
    @State private var hoveredCategory: String?
    @State private var failedCategory: String?

    let onNext: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: Constants.Design.spacingXXL) {
            Spacer()

            headerSection
            categoryGrid

            if let failed = failedCategory {
                errorToast(failed)
            }

            selectionSummary

            Spacer()

            actionButtons
        }
        .padding(.horizontal, Constants.Design.spacingXXL * 2)
        .padding(.bottom, Constants.Design.spacingXXL)
        .onAppear {
            appState.ensureActiveProfile(in: profiles)
        }
        .onChange(of: profiles.count) { _, _ in
            appState.ensureActiveProfile(in: profiles)
        }
    }

    private var onboardingProfile: BlockProfile? {
        appState.activeProfile(from: profiles) ?? profiles.first
    }

    // MARK: - 헤더

    private var headerSection: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            IconBadge(systemName: "hand.raised.fill", color: themeManager.primary, size: 48)

            Text("차단할 사이트/앱을\n선택하세요")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("선택하면 차단 활성, 선택하지 않으면 타이머만 실행됩니다")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 카테고리 그리드

    private var categoryGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 4),
            spacing: Constants.Design.spacingMD
        ) {
            ForEach(Constants.Category.all, id: \.self) { category in
                categoryCard(category)
            }
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
                        modelContext: modelContext,
                        profile: onboardingProfile
                    )
                    failedCategory = nil
                } else {
                    if viewModel.loadPreset(category: category) != nil {
                        viewModel.applyPreset(
                            category: category,
                            modelContext: modelContext,
                            profile: onboardingProfile
                        )
                        failedCategory = nil
                    } else {
                        failedCategory = category
                    }
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: Constants.Design.spacingMD) {
                    IconBadge(
                        systemName: icon,
                        color: isApplied ? themeManager.completed : themeManager.primary,
                        size: 44
                    )

                    Text(Constants.Category.displayName(category))
                        .font(.callout.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Constants.Design.spacingXL)
                .background(
                    isApplied
                        ? themeManager.completed.opacity(0.06)
                        : Color.secondary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                        .stroke(
                            isApplied
                                ? themeManager.completed.opacity(0.4)
                                : Color.secondary.opacity(0.08),
                            lineWidth: isApplied ? 1.5 : 0.5
                        )
                )

                if isApplied {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(themeManager.completed)
                        .background(Circle().fill(.background).padding(-2))
                        .offset(x: -6, y: 6)
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
        .accessibilityLabel(
            "\(Constants.Category.displayName(category)) 카테고리, \(isApplied ? "선택됨" : "선택 안 됨")"
        )
    }

    // MARK: - 에러 토스트

    private func errorToast(_ category: String) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(themeManager.stopButton)
            Text("'\(Constants.Category.displayName(category))' 프리셋을 불러올 수 없습니다")
        }
        .font(.caption)
        .foregroundStyle(themeManager.stopButton)
        .transition(.opacity)
    }

    // MARK: - 선택 요약

    private var selectionSummary: some View {
        Group {
            let siteCount = sites.filter {
                $0.profile?.persistentModelID == onboardingProfile?.persistentModelID
            }.count
            let appCount = apps.filter {
                $0.profile?.persistentModelID == onboardingProfile?.persistentModelID
            }.count

            if siteCount > 0 || appCount > 0 {
                HStack(spacing: Constants.Design.spacingMD) {
                    if siteCount > 0 {
                        Label("\(siteCount)개 사이트", systemImage: "globe")
                    }
                    if appCount > 0 {
                        Label("\(appCount)개 앱", systemImage: "app.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Label("타이머만 사용: 차단 대상이 없어도 진행할 수 있습니다", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.quickEase, value: sites.count)
        .animation(.quickEase, value: apps.count)
    }

    // MARK: - 액션 버튼

    private var actionButtons: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            HStack(spacing: Constants.Design.spacingMD) {
                Button(action: onBack) {
                    Label("이전", systemImage: "chevron.left")
                }
                .secondaryActionStyle(color: .secondary)

                Button(action: onNext) {
                    Text(appliedCategories.isEmpty ? "타이머만 계속" : "다음")
                }
                .primaryActionStyle(color: themeManager.primary)
            }

            Button(action: onSkip) {
                Text("설정 건너뛰고 타이머만 사용")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 헬퍼

    private var appliedCategories: Set<String> {
        let scopedSites = sites.filter {
            $0.profile?.persistentModelID == onboardingProfile?.persistentModelID
        }
        let scopedApps = apps.filter {
            $0.profile?.persistentModelID == onboardingProfile?.persistentModelID
        }
        let modelCategories = Set(
            scopedSites.compactMap(\.category) + scopedApps.compactMap(\.category)
        )
        return Set(Constants.Category.all.filter { modelCategories.contains($0) })
    }
}

#Preview {
    OnboardingBlockStepView(onNext: {}, onBack: {}, onSkip: {})
        .environment(AppState())
        .environment(ThemeManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
        .frame(width: 840, height: 620)
}
