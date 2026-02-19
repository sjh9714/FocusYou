import SwiftUI

// MARK: - Private Relay 경고 패널 공유 컴포넌트

/// iCloud Private Relay가 Safari 차단을 우회하는 경우 표시하는 경고 패널.
/// MainDashboardView와 MenuBarView에서 공유.
struct PrivateRelayWarningPanel: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager

    /// 본문 텍스트 폰트 (대시보드: .callout, 메뉴바: .caption)
    var bodyFont: Font = .callout

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Label(
                "Private Relay가 Safari 차단을 우회 중",
                systemImage: "exclamationmark.shield.fill"
            )
            .font(bodyFont.weight(.semibold))
            .foregroundStyle(themeManager.warning)

            Text("iCloud Private Relay가 켜져 있어 Safari에서 웹사이트 차단이 우회됩니다. 아래 방법 중 하나를 선택하세요.")
                .font(bodyFont)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                Label {
                    Text("Chrome, Firefox 등에서는 정상 차단됩니다.")
                        .font(bodyFont)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                }

                Button {
                    appState.openPrivateRelaySettings()
                } label: {
                    Label("Private Relay 설정 열기", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .primaryActionStyle(color: themeManager.warning)
            }

            Button {
                appState.dismissPrivateRelayWarning()
            } label: {
                Text("닫기")
                    .frame(maxWidth: .infinity)
            }
            .secondaryActionStyle(color: .secondary)
        }
        .frostedCard()
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                .stroke(themeManager.warning.opacity(0.15), lineWidth: 0.5)
        )
    }
}

#Preview {
    PrivateRelayWarningPanel(bodyFont: .callout)
        .environment(AppState())
        .environment(ThemeManager())
        .padding()
}
