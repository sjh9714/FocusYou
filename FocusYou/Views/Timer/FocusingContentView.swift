import SwiftUI

// MARK: - 집중 중 콘텐츠 (v0.5 리디자인)

struct FocusingContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimerViewModel()
    @State private var phaseBadgeScale: CGFloat = 1.0
    @State private var breatheOpacity: Double = 1.0
    @State private var focusQuote: QuoteEntry?

    var body: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            if viewModel.showCancelConfirmation {
                stopConfirmation
            } else {
                countdownDisplay
                capsuleProgressBar
                statusBadge
                motivationQuote
                intentionBadge
                startTimeBadge
                controlButtons
            }
        }
        .animation(.mediumEase, value: viewModel.showCancelConfirmation)
        .onAppear {
            if settingsViewModel.showMotivationQuotes {
                focusQuote = QuoteService.randomQuote()
            }
        }
        .onChange(of: appState.currentPomodoroPhase?.type) { _, newValue in
            guard appState.timerMode == .pomodoro, newValue != nil else { return }
            animatePhaseBadge()
        }
        .onChange(of: appState.focusState) { _, newValue in
            if newValue == .paused {
                startBreatheAnimation()
            } else {
                breatheOpacity = 1.0
            }
        }
    }

    // MARK: - 중지 확인 (인라인)

    private var stopConfirmation: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(themeManager.stopButton)
                .symbolEffect(.pulse, options: .repeating)

            Text("집중을 중지하시겠습니까?")
                .font(.headline)

            Text("차단이 해제되고 세션이 기록됩니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: Constants.Design.spacingMD) {
                Button {
                    viewModel.showCancelConfirmation = false
                } label: {
                    Label("계속 집중", systemImage: "play.fill")
                }
                .secondaryActionStyle(color: themeManager.primary)

                Button {
                    Task {
                        await appState.stopSession(modelContext: modelContext)
                    }
                } label: {
                    Label("중지", systemImage: "stop.fill")
                }
                .primaryActionStyle(color: themeManager.stopButton)
            }
        }
        .frostedCard()
    }

    // MARK: - 파이차트 카운트다운

    @ViewBuilder
    private var countdownDisplay: some View {
        if isFlowmodoroFocus {
            VStack(spacing: Constants.Design.spacingSM) {
                PieChartTimerView(
                    progress: 0,
                    remainingTimeText: "▲ \(appState.timer.elapsedTime.formattedAsTimer)",
                    isPaused: appState.focusState == .paused,
                    activeColor: flowmodoroColor
                )
                Text("멈추면 \(estimatedBreakText) 휴식")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .opacity(breatheOpacity)
        } else {
            PieChartTimerView(
                progress: appState.timer.progress,
                remainingTimeText: appState.timer.remainingTime.formattedAsTimer,
                isPaused: appState.focusState == .paused,
                activeColor: phaseAccentColor
            )
            .opacity(breatheOpacity)
        }
    }

    // MARK: - 캡슐 프로그레스 바

    @ViewBuilder
    private var capsuleProgressBar: some View {
        if isFlowmodoroFocus {
            // 플로우모도로 집중 중: 진행률 없으므로 맥동 바
            Capsule()
                .fill(flowmodoroColor.opacity(0.2))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(flowmodoroColor)
                        .frame(width: 40)
                        .phaseAnimator([false, true]) { content, phase in
                            content
                                .offset(x: phase ? 260 : 0)
                                .opacity(phase ? 0.3 : 0.8)
                        } animation: { _ in
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
                        }
                }
                .clipShape(Capsule())
        } else {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [phaseAccentColor.opacity(0.7), phaseAccentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geometry.size.width * appState.timer.progress))
                        .animation(.easeInOut(duration: 0.8), value: appState.timer.progress)
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
        }
    }

    // MARK: - 상태 뱃지

    private var statusBadge: some View {
        VStack(spacing: Constants.Design.spacingXS) {
            if appState.timerMode == .flowmodoro {
                let isBreak = appState.currentFlowmodoroPhase == .rest
                HStack(spacing: 6) {
                    Image(systemName: isBreak ? "cup.and.saucer.fill" : "waveform.circle.fill")
                        .symbolEffect(.pulse, options: .repeating, isActive: !isBreak)
                    Text(LocalizedStringKey(isBreak ? "휴식 중" : "플로우 중"))
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(flowmodoroColor.opacity(0.12))
                .foregroundStyle(flowmodoroColor)
                .clipShape(Capsule())
                .shadow(color: flowmodoroColor.opacity(0.15), radius: 4, y: 1)
            } else if appState.timerMode == .pomodoro, let phase = appState.currentPomodoroPhase {
                HStack(spacing: 6) {
                    Image(systemName: phase.type == .focus ? "bolt.fill" : "cup.and.saucer.fill")
                        .symbolEffect(.pulse, options: .repeating, isActive: phase.type == .focus)
                    Text(phase.type.displayName)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(phaseAccentColor.opacity(0.12))
                .foregroundStyle(phaseAccentColor)
                .clipShape(Capsule())
                .shadow(color: phaseAccentColor.opacity(0.15), radius: 4, y: 1)
                .scaleEffect(phaseBadgeScale)

                Text(appState.pomodoroCycleProgressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if appState.focusState == .paused {
                HStack(spacing: 6) {
                    Image(systemName: "pause.fill")
                    Text("일시정지됨")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(themeManager.pauseButton.opacity(0.12))
                .foregroundStyle(themeManager.pauseButton)
                .clipShape(Capsule())
            } else {
                Text("집중 중...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 동기부여 명언 (v1.x)

    @ViewBuilder
    private var motivationQuote: some View {
        if settingsViewModel.showMotivationQuotes, let quote = focusQuote {
            Text(quote.text)
                .font(.caption.italic())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 의도 뱃지

    @ViewBuilder
    private var intentionBadge: some View {
        if let intention = appState.currentSession?.intention, !intention.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "target")
                    .font(.caption2)
                Text(intention)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(themeManager.primary.opacity(0.12), in: Capsule())
            .foregroundStyle(themeManager.primary)
        }
    }

    // MARK: - 시작 시간 뱃지

    @ViewBuilder
    private var startTimeBadge: some View {
        if let startedAt = appState.currentSession?.startedAt {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("\(startedAt.formatted(date: .omitted, time: .shortened)) 시작")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 컨트롤 버튼

    private var controlButtons: some View {
        VStack(spacing: Constants.Design.spacingSM) {
            HStack(spacing: Constants.Design.spacingMD) {
                if isFlowmodoroFocus {
                    // 플로우모도로 집중 중: "집중 완료" 주요 버튼
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

            // 취소 잠금 상태 표시
            cancelLockoutBadge
        }
    }

    // MARK: - 취소 강도별 버튼

    @ViewBuilder
    private var cancelButton: some View {
        switch appState.currentCancelIntensity {
        case 2:
            // 하드코어: 비상 해제만 가능
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
            // 강함: 잠금 시간 중에는 비활성
            Button {
                viewModel.requestStop()
            } label: {
                Label("중지", systemImage: "stop.fill")
            }
            .secondaryActionStyle(color: themeManager.stopButton)
            .disabled(!appState.canCancel)
        default:
            // 기본: 확인 다이얼로그
            Button {
                viewModel.requestStop()
            } label: {
                Label("중지", systemImage: "stop.fill")
            }
            .secondaryActionStyle(color: themeManager.stopButton)
        }
    }

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

    // MARK: - Helpers

    private var phaseAccentColor: Color {
        if appState.timerMode == .flowmodoro {
            return flowmodoroColor
        }
        guard appState.timerMode == .pomodoro,
              let phase = appState.currentPomodoroPhase else {
            return themeManager.progress
        }
        return phase.type == .focus ? themeManager.primary : themeManager.secondary
    }

    private var isFlowmodoroFocus: Bool {
        appState.timerMode == .flowmodoro && appState.currentFlowmodoroPhase == .focus
    }

    private var flowmodoroColor: Color {
        if appState.currentFlowmodoroPhase == .rest {
            return themeManager.secondary
        }
        return themeManager.primary
    }

    private var estimatedBreakText: String {
        let breakSeconds = appState.timer.elapsedTime * Constants.Timer.flowmodoroBreakRatio
        return max(breakSeconds, 1).formattedAsReadable
    }

    private func animatePhaseBadge() {
        phaseBadgeScale = 0.85
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            phaseBadgeScale = 1.12
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.15)) {
                phaseBadgeScale = 1.0
            }
        }
    }

    private func startBreatheAnimation() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            breatheOpacity = 0.6
        }
    }
}

#Preview("집중 중") {
    FocusingContentView()
        .environment(AppState())
        .environment(ThemeManager.shared)
        .environment(SettingsViewModel())
        .frame(width: 340)
        .padding()
}
