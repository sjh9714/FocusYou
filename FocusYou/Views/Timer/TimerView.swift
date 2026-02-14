import SwiftUI
import SwiftData

// MARK: - 유휴 상태 콘텐츠 (v0.5 리디자인)

struct IdleContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimerViewModel()
    @Namespace private var modeNamespace

    @Query(sort: \BlockProfile.createdAt)
    private var profiles: [BlockProfile]

    var body: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            profileSelector
            modePicker
            timerDisplay
            timerOptions
            blockSummary
            startButton
            profileQuickStart
        }
        .onAppear {
            appState.ensureActiveProfile(in: profiles)
        }
        .onChange(of: profiles.count) { _, _ in
            appState.ensureActiveProfile(in: profiles)
        }
    }

    private var activeProfile: BlockProfile? {
        appState.activeProfile(from: profiles) ?? profiles.first
    }

    private var activeSites: [BlockedSite] {
        guard let activeProfile else { return [] }
        return activeProfile.blockedSites.filter(\.isEnabled)
    }

    private var activeApps: [BlockedApp] {
        guard let activeProfile else { return [] }
        return activeProfile.blockedApps.filter(\.isEnabled)
    }

    // MARK: - 프로필 선택

    @ViewBuilder
    private var profileSelector: some View {
        if !profiles.isEmpty {
            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                Text("현재 프로필")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                HStack(spacing: Constants.Design.spacingSM) {
                    ForEach(profiles) { profile in
                        let isActive = profile.persistentModelID == activeProfile?.persistentModelID
                        Button {
                            appState.setActiveProfile(profile)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: profile.icon)
                                    .font(.caption2)
                                Text(profile.name)
                                    .font(.caption.weight(.medium))
                            }
                            .padding(.horizontal, Constants.Design.spacingSM)
                            .padding(.vertical, 5)
                            .background(
                                Color(hex: profile.color).opacity(isActive ? 0.2 : 0.08),
                                in: Capsule()
                            )
                            .foregroundStyle(Color(hex: profile.color))
                            .overlay(
                                Capsule()
                                    .stroke(
                                        Color(hex: profile.color).opacity(isActive ? 0.55 : 0),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 모드 피커 (슬라이딩 캡슐)

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(TimerViewModel.TimerMode.allCases, id: \.self) { mode in
                SegmentedPill(
                    title: mode.displayName,
                    tag: mode,
                    selection: Binding(
                        get: { viewModel.selectedMode },
                        set: { viewModel.selectMode($0) }
                    ),
                    namespace: modeNamespace,
                    activeColor: themeManager.primary
                )
            }
        }
        .padding(3)
        .background(Color.secondary.opacity(0.08), in: Capsule())
    }

    // MARK: - 시간 표시

    @ViewBuilder
    private var timerDisplay: some View {
        if viewModel.selectedMode == .flowmodoro {
            Image(systemName: "infinity")
                .font(.system(size: 42, weight: .ultraLight))
                .foregroundStyle(themeManager.textPrimary)
                .accessibilityLabel("플로우모도로 — 시간 제한 없음")
        } else {
            Text(viewModel.initialDurationSeconds.formattedAsTimer)
                .font(.system(size: 42, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(themeManager.textPrimary)
                .contentTransition(.numericText())
                .animation(.mediumEase, value: viewModel.initialDurationSeconds)
                .accessibilityLabel(
                    viewModel.selectedMode == .free
                        ? "\(viewModel.selectedDurationMinutes)분 타이머"
                        : "뽀모도로 집중 \(viewModel.pomodoroConfiguration.focusMinutes)분"
                )
        }
    }

    @ViewBuilder
    private var timerOptions: some View {
        switch viewModel.selectedMode {
        case .free:
            VStack(spacing: Constants.Design.spacingMD) {
                presetChips
                customSlider
            }
        case .pomodoro:
            VStack(spacing: Constants.Design.spacingSM) {
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
        case .flowmodoro:
            VStack(spacing: Constants.Design.spacingSM) {
                Text("원하는 만큼 집중하세요")
                    .font(.callout.weight(.medium))
                Text("집중 시간의 1/5이 휴식으로 자동 부여됩니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
        }
    }

    // MARK: - 프리셋 칩 버튼

    private var presetChips: some View {
        HStack(spacing: Constants.Design.spacingSM) {
            ForEach(Constants.Timer.presets, id: \.self) { minutes in
                ChipButton(
                    title: "\(minutes)분",
                    isSelected: viewModel.selectedPreset == minutes,
                    color: themeManager.primary
                ) {
                    withAnimation(.focusSpring) {
                        viewModel.selectPreset(minutes)
                    }
                }
                .accessibilityLabel("\(minutes)분 프리셋")
            }
        }
    }

    // MARK: - 커스텀 슬라이더

    private var customSlider: some View {
        VStack(spacing: Constants.Design.spacingXS) {
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
            .foregroundStyle(.tertiary)
        }
        .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
    }

    // MARK: - 차단 요약

    @ViewBuilder
    private var blockSummary: some View {
        if !activeSites.isEmpty || !activeApps.isEmpty {
            HStack(spacing: Constants.Design.spacingMD) {
                if !activeSites.isEmpty {
                    Label("\(activeSites.count)개 사이트", systemImage: "globe")
                }
                if !activeApps.isEmpty {
                    Label("\(activeApps.count)개 앱", systemImage: "app.fill")
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
                    sites: activeSites,
                    apps: activeApps,
                    modelContext: modelContext,
                    mode: viewModel.selectedMode.appStateMode,
                    pomodoroConfiguration: viewModel.pomodoroConfiguration
                )
            }
        } label: {
            Label(
                viewModel.selectedMode == .flowmodoro ? "플로우 시작" : "집중 시작",
                systemImage: "bolt.fill"
            )
        }
        .primaryActionStyle(color: themeManager.startButton)
        .disabled(activeProfile == nil)
        .accessibilityLabel("집중 시작")
        .accessibilityHint("타이머를 시작하고 사이트와 앱 차단을 활성화합니다")
    }

    // MARK: - 프로필 빠른 시작

    @ViewBuilder
    private var profileQuickStart: some View {
        if !profiles.isEmpty {
            VStack(spacing: Constants.Design.spacingSM) {
                Text("빠른 시작")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Constants.Design.spacingSM) {
                    ForEach(profiles) { profile in
                        profileChip(profile)
                    }
                }
            }
        }
    }

    private func profileChip(_ profile: BlockProfile) -> some View {
        Button {
            Task {
                await appState.startSessionFromProfile(
                    profile,
                    modelContext: modelContext
                )
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: profile.icon)
                    .font(.caption2)
                Text(profile.name)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, Constants.Design.spacingSM)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                Color(hex: profile.color).opacity(0.1),
                in: Capsule()
            )
            .foregroundStyle(Color(hex: profile.color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(profile.name) 프로필로 집중 시작")
    }
}

// MARK: - 집중 중 콘텐츠 (v0.5 리디자인)

struct FocusingContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimerViewModel()
    @State private var phaseBadgeScale: CGFloat = 1.0
    @State private var breatheOpacity: Double = 1.0

    var body: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            if viewModel.showCancelConfirmation {
                stopConfirmation
            } else {
                countdownDisplay
                capsuleProgressBar
                statusBadge
                controlButtons
            }
        }
        .animation(.mediumEase, value: viewModel.showCancelConfirmation)
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
                    Text(isBreak ? "휴식 중" : "플로우 중")
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

    // MARK: - 컨트롤 버튼

    private var controlButtons: some View {
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

                Button {
                    viewModel.requestStop()
                } label: {
                    Label("취소", systemImage: "xmark")
                }
                .secondaryActionStyle(color: themeManager.stopButton)
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
                        appState.focusState == .paused ? "재개" : "일시정지",
                        systemImage: appState.focusState == .paused ? "play.fill" : "pause.fill"
                    )
                }
                .secondaryActionStyle(color: themeManager.pauseButton)

                Button {
                    viewModel.requestStop()
                } label: {
                    Label("중지", systemImage: "stop.fill")
                }
                .secondaryActionStyle(color: themeManager.stopButton)
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

// MARK: - 완료 콘텐츠 (v0.5 리디자인)

struct CompletedContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]
    @State private var checkScale: CGFloat = 0
    @State private var showSummary = false
    @State private var confettiParticles: [ConfettiParticle] = []

    private var streakInfo: StreakCalculator.StreakInfo {
        StreakCalculator.calculate(from: sessions)
    }

    var body: some View {
        VStack(spacing: Constants.Design.spacingXL) {
            celebrationIcon
            summaryContent
            confirmButton
        }
        .padding(.vertical, Constants.Design.spacingSM)
        .onAppear {
            playCelebration()
            appState.lastCompletedStreakInfo = streakInfo
        }
    }

    // MARK: - 축하 아이콘

    private var celebrationIcon: some View {
        ZStack {
            // 컨페티 파티클
            ForEach(confettiParticles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(particle.offset)
                    .opacity(particle.opacity)
            }

            // 외곽 글로우 링
            Circle()
                .fill(themeManager.completed.opacity(0.08))
                .frame(width: 80, height: 80)
                .scaleEffect(checkScale)

            // 체크마크
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(themeManager.completed)
                .scaleEffect(checkScale)
        }
        .frame(height: 90)
    }

    // MARK: - 요약 콘텐츠

    @ViewBuilder
    private var summaryContent: some View {
        if showSummary {
            VStack(spacing: Constants.Design.spacingMD) {
                Text("집중 완료!")
                    .font(.title3.bold())

                VStack(spacing: Constants.Design.spacingSM) {
                    summaryRow(
                        icon: "clock.fill",
                        color: themeManager.primary,
                        text: appState.completedSummaryText
                    )

                    if let detailText = appState.completedDetailText {
                        summaryRow(
                            icon: "chart.bar.fill",
                            color: themeManager.secondary,
                            text: detailText
                        )
                    }

                    if streakInfo.current > 0 {
                        summaryRow(
                            icon: "flame.fill",
                            color: .orange,
                            text: "\(streakInfo.current)일 연속 집중!"
                        )
                    }
                }
                .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func summaryRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            IconBadge(systemName: icon, color: color, size: 28)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - 확인 버튼

    @ViewBuilder
    private var confirmButton: some View {
        if showSummary {
            Button {
                withAnimation(.focusSpring) {
                    appState.resetToIdle()
                }
            } label: {
                Label("확인", systemImage: "checkmark")
            }
            .primaryActionStyle(color: themeManager.primary)
            .transition(.opacity)
        }
    }

    // MARK: - 축하 애니메이션

    private func playCelebration() {
        // 체크마크 스케일인
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
            checkScale = 1.0
        }

        // 컨페티 버스트
        spawnConfetti()

        // 요약 페이드인
        withAnimation(.mediumEase.delay(0.5)) {
            showSummary = true
        }
    }

    private func spawnConfetti() {
        let colors: [Color] = [
            themeManager.primary,
            themeManager.secondary,
            themeManager.accent,
            themeManager.completed,
        ]

        for i in 0..<12 {
            let angle = Double(i) * (360.0 / 12.0) * .pi / 180
            let distance: CGFloat = CGFloat.random(in: 30...50)
            let particle = ConfettiParticle(
                color: colors[i % colors.count],
                size: CGFloat.random(in: 4...7),
                offset: .zero,
                opacity: 0
            )
            confettiParticles.append(particle)

            let idx = confettiParticles.count - 1

            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                confettiParticles[idx].offset = CGSize(
                    width: cos(angle) * distance,
                    height: sin(angle) * distance
                )
                confettiParticles[idx].opacity = 1
            }

            withAnimation(.easeIn(duration: 0.3).delay(0.6)) {
                confettiParticles[idx].opacity = 0
            }
        }
    }
}

// MARK: - 컨페티 파티클

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var offset: CGSize
    var opacity: Double
}

// MARK: - Previews

#Preview("유휴 상태") {
    IdleContentView()
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
