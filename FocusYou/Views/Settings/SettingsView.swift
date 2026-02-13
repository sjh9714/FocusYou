import SwiftUI

// MARK: - 설정 뷰

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
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var themeSection: some View {
        Section("테마") {
            ForEach(themeManager.availableThemes) { theme in
                Button {
                    themeManager.selectTheme(id: theme.id)
                } label: {
                    HStack(spacing: 10) {
                        themeSwatches(theme)

                        Text(theme.name)
                            .font(.callout)
                            .foregroundStyle(.primary)

                        Spacer()

                        if theme.id == themeManager.selectedThemeID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(themeManager.primary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
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

    private func themeSwatches(_ theme: AppTheme) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: theme.primaryHex))
            Circle()
                .fill(Color(hex: theme.secondaryHex))
            Circle()
                .fill(Color(hex: theme.accentHex))
        }
        .frame(width: 42, height: 12)
    }

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
