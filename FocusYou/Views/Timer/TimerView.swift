import SwiftUI
import SwiftData

// MARK: - 유휴 상태 콘텐츠 (타이머 설정 + 시작 버튼)

struct IdleContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimerViewModel()

    let sites: [BlockedSite]
    let apps: [BlockedApp]

    var body: some View {
        VStack(spacing: 20) {
            modePicker
            timerDisplay
            timerOptions
            blockSummary
            startButton
        }
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(TimerViewModel.TimerMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectMode(mode)
                    }
                } label: {
                    Text(mode.displayName)
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.selectedMode == mode
                                ? themeManager.primary
                                : Color.secondary.opacity(0.15)
                        )
                        .foregroundStyle(
                            viewModel.selectedMode == mode
                                ? .white
                                : themeManager.textPrimary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 시간 표시

    private var timerDisplay: some View {
        Text(viewModel.initialDurationSeconds.formattedAsTimer)
            .font(.system(size: 48, weight: .light, design: .monospaced))
            .foregroundStyle(themeManager.textPrimary)
            .accessibilityLabel(
                viewModel.selectedMode == .free
                    ? "\(viewModel.selectedDurationMinutes)분 타이머"
                    : "뽀모도로 집중 \(viewModel.pomodoroConfiguration.focusMinutes)분"
            )
    }

    @ViewBuilder
    private var timerOptions: some View {
        switch viewModel.selectedMode {
        case .free:
            presetButtons
            customSlider
        case .pomodoro:
            VStack(spacing: 8) {
                Text(viewModel.pomodoroSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PomodoroConfigView(
                    configuration: Binding(
                        get: { viewModel.pomodoroConfiguration },
                        set: { viewModel.pomodoroConfiguration = $0 }
                    )
                )
            }
        }
    }

    // MARK: - 프리셋 버튼

    private var presetButtons: some View {
        HStack(spacing: 8) {
            ForEach(Constants.Timer.presets, id: \.self) { minutes in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectPreset(minutes)
                    }
                } label: {
                    Text("\(minutes)분")
                        .font(.callout)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.selectedPreset == minutes
                                ? themeManager.primary
                                : Color.secondary.opacity(0.15)
                        )
                        .foregroundStyle(
                            viewModel.selectedPreset == minutes
                                ? .white
                                : themeManager.textPrimary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(minutes)분 프리셋")
            }
        }
    }

    // MARK: - 커스텀 슬라이더

    private var customSlider: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { viewModel.customMinutes },
                    set: { viewModel.updateCustomMinutes($0) }
                ),
                in: Double(Constants.Timer.minimumMinutes)...Double(Constants.Timer.maximumMinutes),
                step: 1
            )
            .tint(themeManager.primary)

            HStack {
                Text("\(Constants.Timer.minimumMinutes)분")
                Spacer()
                Text("\(Constants.Timer.maximumMinutes)분")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 차단 요약

    @ViewBuilder
    private var blockSummary: some View {
        if !sites.isEmpty || !apps.isEmpty {
            HStack(spacing: 12) {
                if !sites.isEmpty {
                    Label("\(sites.count)개 사이트", systemImage: "globe")
                }
                if !apps.isEmpty {
                    Label("\(apps.count)개 앱", systemImage: "app.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 시작 버튼

    private var startButton: some View {
        Button {
            Task {
                await appState.startFocusSession(
                    duration: viewModel.initialDurationSeconds,
                    sites: sites,
                    apps: apps,
                    modelContext: modelContext,
                    mode: viewModel.selectedMode == .pomodoro ? .pomodoro : .free,
                    pomodoroConfiguration: viewModel.pomodoroConfiguration
                )
            }
        } label: {
                Text("집중 시작")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(themeManager.startButton)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("집중 시작")
        .accessibilityHint("타이머를 시작하고 사이트와 앱 차단을 활성화합니다")
    }
}

// MARK: - 집중 중 콘텐츠

struct FocusingContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimerViewModel()
    @State private var phaseBadgeScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 20) {
            if viewModel.showCancelConfirmation {
                stopConfirmation
            } else {
                countdownDisplay
                progressBar
                statusText
                controlButtons
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showCancelConfirmation)
        .onChange(of: appState.currentPomodoroPhase?.type) { _, newValue in
            guard appState.timerMode == .pomodoro, newValue != nil else { return }
            animatePhaseBadge()
        }
    }

    // MARK: - 중지 확인 (인라인)

    private var stopConfirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(themeManager.stopButton)

            Text("집중을 중지하시겠습니까?")
                .font(.headline)

            Text("차단이 해제되고 세션이 기록됩니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    viewModel.showCancelConfirmation = false
                } label: {
                    Text("계속 집중하기")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(themeManager.primary.opacity(0.15))
                        .foregroundStyle(themeManager.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await appState.stopSession(modelContext: modelContext)
                    }
                } label: {
                        Text("중지")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        .background(themeManager.stopButton)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    private var countdownDisplay: some View {
        PieChartTimerView(
            progress: appState.timer.progress,
            remainingTimeText: appState.timer.remainingTime.formattedAsTimer,
            isPaused: appState.focusState == .paused,
            activeColor: phaseAccentColor
        )
    }

    private var progressBar: some View {
        ProgressView(value: appState.timer.progress)
            .tint(phaseAccentColor)
            .animation(.easeInOut, value: appState.timer.progress)
    }

    private var statusText: some View {
        VStack(spacing: 4) {
            if appState.timerMode == .pomodoro, let phase = appState.currentPomodoroPhase {
                HStack(spacing: 6) {
                    Image(systemName: phase.type == .focus ? "bolt.fill" : "cup.and.saucer.fill")
                    Text(phase.type.displayName)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(phaseAccentColor.opacity(0.16))
                    .foregroundStyle(
                        phaseAccentColor
                    )
                .clipShape(Capsule())
                .scaleEffect(phaseBadgeScale)
                Text(appState.pomodoroCycleProgressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if appState.focusState == .paused {
                Text("일시정지됨")
                    .font(.callout)
                    .foregroundStyle(themeManager.pauseButton)
            } else {
                Text("집중 중...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var phaseAccentColor: Color {
        guard appState.timerMode == .pomodoro,
              let phase = appState.currentPomodoroPhase else {
            return themeManager.progress
        }
        return phase.type == .focus ? themeManager.primary : themeManager.secondary
    }

    private func animatePhaseBadge() {
        phaseBadgeScale = 0.9
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0.1)) {
            phaseBadgeScale = 1.08
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.18)) {
                phaseBadgeScale = 1.0
            }
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            // 일시정지 / 재개
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    if appState.focusState == .paused {
                        appState.resumeSession()
                    } else {
                        appState.pauseSession()
                    }
                }
            } label: {
                Label(
                    appState.focusState == .paused ? "재개" : "일시정지",
                    systemImage: appState.focusState == .paused
                        ? "play.fill" : "pause.fill"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(themeManager.pauseButton.opacity(0.15))
                .foregroundStyle(themeManager.pauseButton)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            // 중지
            Button {
                viewModel.requestStop()
            } label: {
                Label("중지", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(themeManager.stopButton.opacity(0.15))
                    .foregroundStyle(themeManager.stopButton)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 완료 콘텐츠

struct CompletedContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(themeManager.completed)

            Text("집중 완료!")
                .font(.title2.bold())

            Text(appState.completedSummaryText)
                .font(.callout)
                .foregroundStyle(.secondary)

            if let completedDetailText = appState.completedDetailText {
                Text(completedDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    appState.resetToIdle()
                }
            } label: {
                Text("확인")
                    .font(.callout.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(themeManager.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Previews

#Preview("유휴 상태") {
    IdleContentView(sites: [], apps: [])
        .environment(AppState())
        .environment(ThemeManager.shared)
        .frame(width: 340)
        .padding()
}

#Preview("집중 중") {
    FocusingContentView()
        .environment(AppState())
        .environment(ThemeManager.shared)
        .frame(width: 340)
        .padding()
}

#Preview("완료") {
    CompletedContentView()
        .environment(AppState())
        .environment(ThemeManager.shared)
        .frame(width: 340)
        .padding()
}
