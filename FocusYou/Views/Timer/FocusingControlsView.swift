import SwiftUI

// MARK: - 집중 중 제어 버튼

struct FocusingControlsView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext

    let onRequestStop: () -> Void
    let isFlowmodoroFocus: Bool
    let flowmodoroColor: Color

    var body: some View {
        VStack(spacing: Constants.Design.spacingSM) {
            HStack(spacing: Constants.Design.spacingMD) {
                if isFlowmodoroFocus {
                    Button {
                        Task {
                            await appState.finishFlowmodoroFocus(modelContext: modelContext)
                        }
                    } label: {
                        Label("집중 완료", systemImage: "checkmark.circle.fill")
                    }
                    .primaryActionStyle(color: flowmodoroColor)

                    cancelButton
                } else {
                    Button {
                        withAnimation(.focusSpring) {
                            if appState.focusState == .paused {
                                appState.resumeSession()
                            } else {
                                appState.pauseSession()
                            }
                        }
                    } label: {
                        Label(
                            LocalizedStringKey(appState.focusState == .paused ? "재개" : "일시정지"),
                            systemImage: appState.focusState == .paused ? "play.fill" : "pause.fill"
                        )
                    }
                    .secondaryActionStyle(color: themeManager.pauseButton)

                    cancelButton
                }
            }

            cancelLockoutBadge
        }
    }

    // MARK: - 취소 강도별 버튼

    @ViewBuilder
    private var cancelButton: some View {
        switch appState.currentCancelIntensity {
        case 2:
            if appState.isEmergencyUnlockActive {
                emergencyUnlockView
            } else {
                Button {
                    appState.requestEmergencyUnlock()
                } label: {
                    Label("비상 해제", systemImage: "exclamationmark.shield.fill")
                }
                .secondaryActionStyle(color: themeManager.stopButton)
                .disabled(appState.emergencyUnlockUsedToday)
            }
        case 1:
            Button {
                onRequestStop()
            } label: {
                Label("중지", systemImage: "stop.fill")
            }
            .secondaryActionStyle(color: themeManager.stopButton)
            .disabled(!appState.canCancel)
        default:
            Button {
                onRequestStop()
            } label: {
                Label("중지", systemImage: "stop.fill")
            }
            .secondaryActionStyle(color: themeManager.stopButton)
        }
    }

    // MARK: - 잠금 배지

    @ViewBuilder
    private var cancelLockoutBadge: some View {
        if appState.currentCancelIntensity == 1, !appState.canCancel {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("중지 잠금 \(Int(appState.cancelLockoutRemainingSeconds))초 남음")
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(themeManager.stopButton.opacity(0.7))
        } else if appState.currentCancelIntensity == 2 && !appState.isEmergencyUnlockActive {
            HStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption2)
                Text(
                    LocalizedStringKey(
                        appState.emergencyUnlockUsedToday
                            ? "오늘 비상 해제를 이미 사용했습니다"
                            : "하드코어 모드 — 비상 해제만 가능"
                    )
                )
                .font(.caption)
            }
            .foregroundStyle(themeManager.stopButton.opacity(0.7))
        }
    }

    // MARK: - 비상 해제

    @ViewBuilder
    private var emergencyUnlockView: some View {
        VStack(spacing: Constants.Design.spacingSM) {
            if appState.emergencyUnlockCountdown > 0 {
                Text("\(Int(appState.emergencyUnlockCountdown))초 대기 중...")
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(themeManager.stopButton)

                Button {
                    appState.cancelEmergencyUnlock()
                } label: {
                    Label("취소", systemImage: "xmark")
                }
                .secondaryActionStyle(color: .secondary)
            } else {
                Button {
                    Task {
                        await appState.confirmEmergencyUnlock(modelContext: modelContext)
                    }
                } label: {
                    Label("비상 해제 확인", systemImage: "exclamationmark.triangle.fill")
                }
                .primaryActionStyle(color: themeManager.stopButton)
            }
        }
    }
}

#Preview {
    FocusingControlsView(
        onRequestStop: {},
        isFlowmodoroFocus: false,
        flowmodoroColor: .green
    )
    .environment(AppState())
    .environment(ThemeManager.shared)
    .padding()
}
