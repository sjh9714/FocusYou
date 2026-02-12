import SwiftUI

// MARK: - 설정 뷰

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel

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
        .frame(width: 400)
}
