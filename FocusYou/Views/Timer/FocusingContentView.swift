import SwiftUI

// MARK: - 집중 중 콘텐츠 (v0.5 리디자인)

struct FocusingContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimerViewModel()
    @State private var breatheOpacity: Double = 1.0
    @State private var focusQuote: QuoteEntry?

    var body: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            if viewModel.showCancelConfirmation {
                stopConfirmation
            } else {
                countdownDisplay
                capsuleProgressBar
                FocusingStatusView(
                    phaseAccentColor: phaseAccentColor,
                    flowmodoroColor: flowmodoroColor,
                    focusQuote: focusQuote
                )
                FocusingControlsView(
                    onRequestStop: { viewModel.requestStop() },
                    isFlowmodoroFocus: isFlowmodoroFocus,
                    flowmodoroColor: flowmodoroColor
                )
            }
        }
        .animation(.mediumEase, value: viewModel.showCancelConfirmation)
        .onAppear {
            if settingsViewModel.showMotivationQuotes {
                focusQuote = QuoteService.randomQuote()
            }
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
