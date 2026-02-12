import SwiftUI
import SwiftData

// MARK: - 유휴 상태 콘텐츠 (타이머 설정 + 시작 버튼)

struct IdleContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimerViewModel()

    let sites: [BlockedSite]
    let apps: [BlockedApp]

    var body: some View {
        VStack(spacing: 20) {
            timerDisplay
            presetButtons
            customSlider
            blockSummary
            startButton
        }
    }

    // MARK: - 시간 표시

    private var timerDisplay: some View {
        Text(TimeInterval(viewModel.selectedDurationMinutes * 60).formattedAsTimer)
            .font(.system(size: 48, weight: .light, design: .monospaced))
            .foregroundStyle(ThemeManager.shared.textPrimary)
            .accessibilityLabel("\(viewModel.selectedDurationMinutes)분 타이머")
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
                                ? ThemeManager.shared.primary
                                : Color.secondary.opacity(0.15)
                        )
                        .foregroundStyle(
                            viewModel.selectedPreset == minutes
                                ? .white
                                : ThemeManager.shared.textPrimary
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
            .tint(ThemeManager.shared.primary)

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
                    duration: viewModel.selectedDurationSeconds,
                    sites: sites,
                    apps: apps,
                    modelContext: modelContext
                )
            }
        } label: {
            Text("집중 시작")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(ThemeManager.shared.startButton)
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
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimerViewModel()

    var body: some View {
        VStack(spacing: 20) {
            countdownDisplay
            progressBar
            statusText
            controlButtons
        }
        .alert(
            "집중을 중지하시겠습니까?",
            isPresented: $viewModel.showCancelConfirmation
        ) {
            Button("계속 집중하기", role: .cancel) {}
            Button("중지", role: .destructive) {
                Task {
                    await appState.stopSession(modelContext: modelContext)
                }
            }
        } message: {
            Text("차단이 해제되고 세션이 기록됩니다.")
        }
    }

    private var countdownDisplay: some View {
        Text(appState.timer.remainingTime.formattedAsTimer)
            .font(.system(size: 56, weight: .light, design: .monospaced))
            .foregroundStyle(
                appState.focusState == .paused
                    ? ThemeManager.shared.textSecondary
                    : ThemeManager.shared.primary
            )
            .accessibilityLabel("남은 시간 \(appState.timer.remainingTime.formattedAsTimer)")
    }

    private var progressBar: some View {
        ProgressView(value: appState.timer.progress)
            .tint(ThemeManager.shared.progress)
            .animation(.easeInOut, value: appState.timer.progress)
    }

    private var statusText: some View {
        Group {
            if appState.focusState == .paused {
                Text("일시정지됨")
                    .foregroundStyle(ThemeManager.shared.pauseButton)
            } else {
                Text("집중 중...")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
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
                .background(ThemeManager.shared.pauseButton.opacity(0.15))
                .foregroundStyle(ThemeManager.shared.pauseButton)
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
                    .background(ThemeManager.shared.stopButton.opacity(0.15))
                    .foregroundStyle(ThemeManager.shared.stopButton)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 완료 콘텐츠

struct CompletedContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(ThemeManager.shared.completed)

            Text("집중 완료!")
                .font(.title2.bold())

            Text(appState.timer.totalDuration.formattedAsReadable + " 집중했습니다")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    appState.resetToIdle()
                }
            } label: {
                Text("확인")
                    .font(.callout.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(ThemeManager.shared.primary)
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
        .frame(width: 340)
        .padding()
}

#Preview("집중 중") {
    FocusingContentView()
        .environment(AppState())
        .frame(width: 340)
        .padding()
}

#Preview("완료") {
    CompletedContentView()
        .environment(AppState())
        .frame(width: 340)
        .padding()
}
