import SwiftUI

// MARK: - 대시보드 활성 히어로 카드

struct DashboardActiveHeroView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext

    @State private var showStopConfirmation = false
    @State private var isSessionActionInFlight = false
    @State private var focusQuote: QuoteEntry?

    let statusTitle: String

    var body: some View {
        if let scheduleName = appState.activeScheduleName {
            scheduleBanner(scheduleName)
        }

        HStack(spacing: Constants.Design.spacingXL) {
            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                Text(statusTitle)
                    .font(.headline)

                Text(statusDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(blockingActivityText, systemImage: appState.isBlockingActive ? "checkmark.shield.fill" : "timer")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(appState.isBlockingActive ? themeManager.primary : .secondary)

                if let intention = appState.currentSession?.intention, !intention.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.caption2)
                        Text(intention)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(themeManager.primary)
                }

                if let startedAt = appState.currentSession?.startedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(startedAt.formatted(date: .omitted, time: .shortened)) 시작")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                if showStopConfirmation {
                    stopConfirmationView
                } else {
                    HStack(spacing: Constants.Design.spacingSM) {
                        if isFlowmodoroFocus {
                            Button {
                                finishFlowmodoro()
                            } label: {
                                Label("집중 완료", systemImage: "checkmark.circle.fill")
                            }
                            .primaryActionStyle(color: themeManager.primary)
                            .disabled(isSessionActionInFlight)
                        } else {
                            Button {
                                if appState.focusState == .paused {
                                    appState.resumeSession()
                                } else {
                                    appState.pauseSession()
                                }
                            } label: {
                                Label(
                                    LocalizedStringKey(appState.focusState == .paused ? "재개" : "일시정지"),
                                    systemImage: appState.focusState == .paused ? "play.fill" : "pause.fill"
                                )
                            }
                            .secondaryActionStyle(color: themeManager.pauseButton)
                            .disabled(isSessionActionInFlight)
                        }

                        cancelButton
                    }

                    cancelLockoutBadge
                }
            }

            Spacer()

            VStack(spacing: Constants.Design.spacingXS) {
                Text(remainingTimerText)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(themeManager.primary)

                Text(isFlowmodoroFocus ? "경과 시간" : "남은 시간")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frostedCard()
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                .stroke(themeManager.primary.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            if settingsViewModel.showMotivationQuotes {
                focusQuote = QuoteService.randomQuote()
            }
        }

        if settingsViewModel.showMotivationQuotes, let quote = focusQuote {
            quoteCard(quote)
        }
    }

    private var blockingActivityText: String {
        appState.isBlockingActive
            ? String(localized: "차단 활성")
            : String(localized: "타이머만 실행 중")
    }

    // MARK: - 동기부여 명언

    private func quoteCard(_ quote: QuoteEntry) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            Image(systemName: "quote.opening")
                .font(.caption2)
                .foregroundStyle(themeManager.accent.opacity(0.6))

            Text(quote.text)
                .font(.caption.italic())
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text("— \(quote.author)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedCard()
        .onTapGesture {
            withAnimation(.quickEase) {
                focusQuote = QuoteService.randomQuote()
            }
        }
    }

    // MARK: - 중지 확인

    private var stopConfirmationView: some View {
        VStack(spacing: Constants.Design.spacingSM) {
            Text("집중을 중지하시겠습니까?")
                .font(.callout.weight(.medium))

            HStack(spacing: Constants.Design.spacingSM) {
                Button {
                    showStopConfirmation = false
                } label: {
                    Label("계속 집중", systemImage: "play.fill")
                }
                .secondaryActionStyle(color: themeManager.primary)

                Button {
                    stopSession()
                } label: {
                    Label("중지", systemImage: "stop.fill")
                }
                .primaryActionStyle(color: themeManager.stopButton)
            }
        }
    }

    // MARK: - 취소 버튼

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
                .disabled(appState.emergencyUnlockUsedToday || isSessionActionInFlight)
            }
        case 1:
            Button {
                showStopConfirmation = true
            } label: {
                Label("중지", systemImage: "stop.fill")
            }
            .secondaryActionStyle(color: themeManager.stopButton)
            .disabled(!appState.canCancel || isSessionActionInFlight)
        default:
            Button {
                showStopConfirmation = true
            } label: {
                Label("중지", systemImage: "stop.fill")
            }
            .secondaryActionStyle(color: themeManager.stopButton)
            .disabled(isSessionActionInFlight)
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
        } else if appState.currentCancelIntensity == 2, !appState.isEmergencyUnlockActive {
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

    private var emergencyUnlockView: some View {
        VStack(spacing: Constants.Design.spacingXS) {
            if appState.emergencyUnlockCountdown > 0 {
                Text("\(Int(appState.emergencyUnlockCountdown))초 대기 중...")
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(themeManager.stopButton)
            }

            HStack(spacing: Constants.Design.spacingSM) {
                Button {
                    appState.cancelEmergencyUnlock()
                } label: {
                    Label("취소", systemImage: "xmark")
                }
                .secondaryActionStyle(color: themeManager.primary)

                Button {
                    Task {
                        await appState.confirmEmergencyUnlock(modelContext: modelContext)
                    }
                } label: {
                    Label("해제 확인", systemImage: "lock.open.fill")
                }
                .primaryActionStyle(color: themeManager.stopButton)
                .disabled(appState.emergencyUnlockCountdown > 0)
            }
        }
    }

    // MARK: - 스케줄 배너

    private func scheduleBanner(_ name: String) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            Image(systemName: "calendar.badge.clock")
                .font(.callout)
                .foregroundStyle(themeManager.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("진행 중인 스케줄")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.primary)
            }

            Spacer()
        }
        .padding(Constants.Design.spacingMD)
        .background(themeManager.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerMD))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                .stroke(themeManager.primary.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - 상태 텍스트

    private var statusDetailText: String {
        if appState.timerMode == .pomodoro {
            return "\(appState.pomodoroPhaseTitle) · \(appState.pomodoroCycleProgressText)"
        }
        if appState.timerMode == .flowmodoro {
            let isBreak = appState.currentFlowmodoroPhase == .rest
            return isBreak ? String(localized: "휴식 카운트다운") : String(localized: "플로우모도로")
        }
        return String(localized: "자유 타이머")
    }

    private var remainingTimerText: String {
        if isFlowmodoroFocus {
            return "▲ \(appState.timer.elapsedTime.formattedAsTimer)"
        }
        return appState.timer.remainingTime.formattedAsTimer
    }

    private var isFlowmodoroFocus: Bool {
        appState.timerMode == .flowmodoro && appState.currentFlowmodoroPhase == .focus
    }

    // MARK: - 세션 액션

    private func finishFlowmodoro() {
        guard !isSessionActionInFlight else { return }
        isSessionActionInFlight = true

        Task { @MainActor in
            await appState.finishFlowmodoroFocus(modelContext: modelContext)
            isSessionActionInFlight = false
        }
    }

    private func stopSession() {
        guard !isSessionActionInFlight else { return }
        isSessionActionInFlight = true

        Task { @MainActor in
            await appState.stopSession(modelContext: modelContext)
            isSessionActionInFlight = false
            showStopConfirmation = false
        }
    }
}

#Preview {
    DashboardActiveHeroView(statusTitle: "집중 진행 중")
        .environment(AppState())
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .modelContainer(for: [FocusSession.self], inMemory: true)
        .padding()
}
