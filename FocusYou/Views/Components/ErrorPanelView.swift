import SwiftUI

// MARK: - 에러 패널 공유 컴포넌트

/// 차단 해제 실패 등의 에러를 표시하는 패널.
/// MainDashboardView와 MenuBarView에서 공유.
struct ErrorPanelView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager

    /// 본문 텍스트 폰트 (대시보드: .callout, 메뉴바: .caption)
    var bodyFont: Font = .callout

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Label("오류", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(themeManager.stopButton)

            Text(appState.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
                .font(bodyFont)
                .foregroundStyle(.secondary)

            HStack(spacing: Constants.Design.spacingSM) {
                if appState.canRetryBlockingDeactivation {
                    Button {
                        Task {
                            await appState.retryBlockingDeactivation()
                        }
                    } label: {
                        Text("다시 시도")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionStyle(color: themeManager.stopButton)
                }

                Button {
                    appState.dismissError()
                } label: {
                    Text("닫기")
                        .frame(maxWidth: .infinity)
                }
                .secondaryActionStyle(color: .secondary)
            }
        }
        .frostedCard()
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                .stroke(themeManager.stopButton.opacity(0.15), lineWidth: 0.5)
        )
    }
}

#Preview {
    ErrorPanelView(bodyFont: .callout)
        .environment(AppState())
        .environment(ThemeManager())
        .padding()
}
