import SwiftUI

// MARK: - 설정 뷰 (v0.5 리디자인)

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section("일반") {
                Toggle(
                    "메뉴바에 남은 시간 표시",
                    isOn: Bindable(viewModel).showMenuBarTime
                )

                Toggle(
                    "완료 시 사운드 재생",
                    isOn: Bindable(viewModel).playCompletionSound
                )

                Toggle(
                    "차단된 앱 알림",
                    isOn: Bindable(viewModel).showBlockedAppNotification
                )
            }

            themeSection

            #if DEBUG
            debugSection
            #endif

            Section("정보") {
                LabeledContent("버전", value: appVersionText)
                LabeledContent("개발", value: "Focus You")
            }
        }
        .formStyle(.grouped)
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    // MARK: - 테마 섹션

    private var themeSection: some View {
        Section("테마") {
            ForEach(themeManager.availableThemes) { theme in
                themeRow(theme)
            }

            Text("선택한 테마는 메뉴바/타이머/버튼에 즉시 반영됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                openWindow(id: "main-dashboard")
            } label: {
                Label("대시보드에서 미리보기", systemImage: "rectangle.on.rectangle")
            }
        }
    }

    private func themeRow(_ theme: AppTheme) -> some View {
        let isSelected = theme.id == themeManager.selectedThemeID

        return Button {
            withAnimation(.quickEase) {
                themeManager.selectTheme(id: theme.id)
            }
        } label: {
            HStack(spacing: Constants.Design.spacingMD) {
                // 확대된 색상 스와치
                themeSwatches(theme, isSelected: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)

                    // 미니 프리뷰 칩
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

    // MARK: - 디버그

    #if DEBUG
    private var debugSection: some View {
        Section("개발자") {
            Toggle(
                "Fast Timer (디버그)",
                isOn: Bindable(viewModel).debugFastTimerEnabled
            )

            HStack {
                Text("1분 = \(Int(viewModel.debugSecondsPerMinute))초")
                Spacer()
                Stepper(
                    "",
                    value: Bindable(viewModel).debugSecondsPerMinute,
                    in: Constants.Settings.debugSecondsPerMinuteRange,
                    step: 1
                )
                .labelsHidden()
                .disabled(!viewModel.debugFastTimerEnabled)
            }

            Text("세션 QA를 빠르게 검증할 때만 사용됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    #endif
}

#Preview {
    SettingsView()
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .frame(width: 400)
}
