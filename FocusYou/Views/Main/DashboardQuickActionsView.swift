import SwiftUI

// MARK: - 퀵 액션 바 + 테마 피커

struct DashboardQuickActionsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.openWindow) private var openWindow

    @Binding var showThemePicker: Bool

    var body: some View {
        HStack(spacing: Constants.Design.spacingMD) {
            dashboardAction(title: "차단 목록", symbol: "list.bullet.rectangle", tint: themeManager.primary) {
                openWindow(id: "block-list")
            }
            dashboardAction(title: "설정", symbol: "gearshape", tint: themeManager.accent) {
                openWindow(id: "settings")
            }

            // 테마 퀵 피커
            Button {
                showThemePicker.toggle()
            } label: {
                HStack(spacing: Constants.Design.spacingSM) {
                    Text(themeManager.selectedTheme.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Circle().fill(themeManager.primary).frame(width: 10, height: 10)
                        Circle().fill(themeManager.secondary).frame(width: 10, height: 10)
                        Circle().fill(themeManager.accent).frame(width: 10, height: 10)
                    }

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
            .popover(isPresented: $showThemePicker) {
                themePickerPopover
            }
        }
    }

    private func dashboardAction(
        title: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(LocalizedStringKey(title), systemImage: symbol)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .secondaryActionStyle(color: tint)
    }

    // MARK: - 테마 피커 팝오버

    private var themePickerPopover: some View {
        VStack(spacing: 0) {
            Text("테마 선택")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Constants.Design.spacingMD)
                .padding(.vertical, Constants.Design.spacingSM)

            Rectangle().fill(.quaternary).frame(height: 0.5)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(themeManager.availableThemes) { theme in
                        let isSelected = theme.id == themeManager.selectedThemeID

                        Button {
                            withAnimation(.quickEase) {
                                themeManager.selectTheme(id: theme.id)
                            }
                        } label: {
                            HStack(spacing: Constants.Design.spacingSM) {
                                HStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: theme.primaryHex))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: theme.secondaryHex))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: theme.accentHex))
                                }
                                .frame(width: 40, height: 12)
                                .clipShape(RoundedRectangle(cornerRadius: 3))

                                Text(theme.name)
                                    .font(.callout)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color(hex: theme.primaryHex))
                                }
                            }
                            .padding(.horizontal, Constants.Design.spacingMD)
                            .padding(.vertical, Constants.Design.spacingSM)
                            .background(
                                isSelected
                                    ? Color(hex: theme.primaryHex).opacity(0.06)
                                    : Color.clear
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 220, height: 340)
    }
}

#Preview {
    DashboardQuickActionsView(showThemePicker: .constant(false))
        .environment(ThemeManager.shared)
        .padding()
}
