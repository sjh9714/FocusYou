import SwiftUI

// MARK: - 설정: 테마 섹션

struct SettingsThemeSectionView: View {
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LicenseManager.self) private var licenseManager

    @Binding var expandedThemeCategory: String?
    @Binding var showPaywall: Bool
    @Binding var paywallReason: PaywallReason

    var body: some View {
        Section("테마") {
            ForEach(themeManager.themesByCategory, id: \.category) { group in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedThemeCategory == group.category },
                        set: { expandedThemeCategory = $0 ? group.category : nil }
                    )
                ) {
                    ForEach(group.themes) { theme in
                        themeRow(theme)
                    }
                } label: {
                    Label(
                        Constants.ThemeCategory.displayName(group.category),
                        systemImage: Constants.ThemeCategory.icons[group.category] ?? "circle.fill"
                    )
                    .font(.callout.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.quickEase) {
                            if expandedThemeCategory == group.category {
                                expandedThemeCategory = nil
                            } else {
                                expandedThemeCategory = group.category
                            }
                        }
                    }
                }
            }

            Text("선택한 테마는 메뉴바/타이머/버튼에 즉시 반영됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ThemeLivePreviewPanel()
        }
    }

    // MARK: - 테마 행

    private func themeRow(_ theme: AppTheme) -> some View {
        let isSelected = theme.id == themeManager.selectedThemeID
        let isLocked = !licenseManager.isPro && !themeManager.isThemeFree(theme)

        return Button {
            if isLocked {
                paywallReason = .themeLimit
                showPaywall = true
            } else {
                withAnimation(.quickEase) {
                    themeManager.selectTheme(id: theme.id)
                }
            }
        } label: {
            HStack(spacing: Constants.Design.spacingMD) {
                themeSwatches(theme, isSelected: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Constants.Design.spacingXS) {
                        Text(theme.name)
                            .font(.callout.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isLocked ? .secondary : .primary)
                        if isLocked {
                            ProBadge()
                        }
                    }

                    miniTimerPreview(theme)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: theme.primaryHex))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, Constants.Design.spacingSM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 색상 스워치

    private func themeSwatches(_ theme: AppTheme, isSelected: Bool) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: theme.primaryHex))
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: theme.secondaryHex))
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: theme.accentHex))
        }
        .frame(width: 60, height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    isSelected ? Color(hex: theme.primaryHex).opacity(0.5) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: isSelected ? Color(hex: theme.primaryHex).opacity(0.15) : .clear,
            radius: 4
        )
    }

    // MARK: - 미니 타이머 프리뷰

    private func miniTimerPreview(_ theme: AppTheme) -> some View {
        Text("25:00")
            .font(.caption2.weight(.medium).monospacedDigit())
            .foregroundStyle(Color(hex: theme.primaryHex))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Color(hex: theme.primaryHex).opacity(0.1),
                in: RoundedRectangle(cornerRadius: Constants.Design.cornerSM)
            )
    }
}

#Preview {
    Form {
        SettingsThemeSectionView(
            expandedThemeCategory: .constant(nil),
            showPaywall: .constant(false),
            paywallReason: .constant(.themeLimit)
        )
    }
    .formStyle(.grouped)
    .environment(SettingsViewModel())
    .environment(ThemeManager.shared)
    .environment(LicenseManager.shared)
    .frame(width: 400)
}
