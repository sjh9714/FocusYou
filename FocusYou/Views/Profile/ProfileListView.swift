import SwiftUI
import SwiftData

// MARK: - 프로필 목록 뷰 (v0.5)

struct ProfileListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \BlockProfile.createdAt, order: .reverse)
    private var profiles: [BlockProfile]
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("차단 프로필")
                    .font(.title3.bold())
                Spacer()
                Button {
                    viewModel.prepareNewProfile()
                } label: {
                    Label("새 프로필", systemImage: "plus.circle.fill")
                        .font(.callout.weight(.semibold))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(themeManager.primary)
            }
            .padding()

            Rectangle().fill(.quaternary).frame(height: 0.5)

            // 목록
            if profiles.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Constants.Design.spacingMD) {
                        ForEach(profiles) { profile in
                            profileCard(profile)
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $viewModel.showEditor) {
            ProfileEditorView(viewModel: viewModel)
                .environment(themeManager)
        }
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            Spacer()

            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("프로필이 없습니다")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("프로필을 만들면 상황별로 다른 차단 설정을 빠르게 적용할 수 있습니다.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button {
                viewModel.prepareNewProfile()
            } label: {
                Label("첫 프로필 만들기", systemImage: "plus")
            }
            .primaryActionStyle(color: themeManager.primary)
            .frame(width: 200)

            Spacer()
        }
    }

    // MARK: - 프로필 카드

    private func profileCard(_ profile: BlockProfile) -> some View {
        HStack(spacing: Constants.Design.spacingMD) {
            // 색상 스트립
            Rectangle()
                .fill(Color(hex: profile.color))
                .frame(width: 4)
                .clipShape(Capsule())

            // 아이콘
            IconBadge(
                systemName: profile.icon,
                color: Color(hex: profile.color),
                size: 40
            )

            // 정보
            VStack(alignment: .leading, spacing: Constants.Design.spacingXS) {
                HStack(spacing: Constants.Design.spacingSM) {
                    Text(profile.name)
                        .font(.callout.weight(.semibold))

                    if profile.isDefault {
                        Text("기본")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeManager.primary.opacity(0.1))
                            .foregroundStyle(themeManager.primary)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: Constants.Design.spacingSM) {
                    Label(
                        profile.timerMode == "pomodoro" ? "뽀모도로" : "자유",
                        systemImage: profile.timerMode == "pomodoro" ? "clock.fill" : "timer"
                    )
                    Text("·")
                    Text("\(profile.focusDuration / 60)분")
                    Text("·")
                    Text("\(profile.blockedSites.count)사이트 \(profile.blockedApps.count)앱")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // 액션
            Menu {
                Button {
                    viewModel.prepareEdit(profile)
                } label: {
                    Label("편집", systemImage: "pencil")
                }

                if !profile.isDefault {
                    Divider()
                    Button(role: .destructive) {
                        withAnimation(.quickEase) {
                            viewModel.delete(profile, modelContext: modelContext)
                        }
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 64)
        .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
    }
}

#Preview {
    ProfileListView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
        .frame(width: 500, height: 400)
}
