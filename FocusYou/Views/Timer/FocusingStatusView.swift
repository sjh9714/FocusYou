import SwiftUI

// MARK: - 집중 중 상태 뱃지 및 정보

struct FocusingStatusView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SettingsViewModel.self) private var settingsViewModel

    @State private var phaseBadgeScale: CGFloat = 1.0

    let phaseAccentColor: Color
    let flowmodoroColor: Color
    let focusQuote: QuoteEntry?

    var body: some View {
        statusBadge
        motivationQuote
        intentionBadge
        startTimeBadge
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
        .onChange(of: appState.currentPomodoroPhase?.type) { _, newValue in
            guard appState.timerMode == .pomodoro, newValue != nil else { return }
            animatePhaseBadge()
        }
    }

    // MARK: - 동기부여 명언

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

    // MARK: - 애니메이션

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
}

#Preview {
    FocusingStatusView(
        phaseAccentColor: .blue,
        flowmodoroColor: .green,
        focusQuote: nil
    )
    .environment(AppState())
    .environment(ThemeManager.shared)
    .environment(SettingsViewModel())
    .padding()
}
