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

            Section("정보") {
                LabeledContent("버전", value: "0.1.0")
                LabeledContent("개발", value: "Focus You")
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
        .environment(SettingsViewModel())
        .frame(width: 400)
}
