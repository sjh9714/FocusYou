import SwiftUI
import SwiftData

// MARK: - 유휴 상태 콘텐츠 (v0.5 리디자인)

struct IdleContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(LicenseManager.self) private var licenseManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimerViewModel()
    @State private var showIntentionInput = false
    @State private var intentionText = ""
    @State private var showPaywall = false
    @State private var burnoutDetector = BurnoutDetector.shared
    @Namespace private var modeNamespace

    @Query(sort: \BlockProfile.createdAt)
    private var profiles: [BlockProfile]

    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var allSessions: [FocusSession]

    /// 최근 의도 (완료 세션에서 중복 제거, 최대 5개)
    private var recentIntentions: [String] {
        var seen = Set<String>()
        var result = [String]()
        for session in allSessions where session.wasCompleted {
            guard let intention = session.intention,
                  !intention.isEmpty,
                  !seen.contains(intention) else { continue }
            seen.insert(intention)
            result.append(intention)
            if result.count >= 5 { break }
        }
        return result
    }

    var body: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            // 번아웃 배너 (v1.5)
            if burnoutDetector.showBanner {
                BurnoutBannerView(
                    message: burnoutDetector.bannerMessage,
                    onDismiss: { burnoutDetector.dismissBanner() }
                )
            }

            if showIntentionInput {
                IntentionInputView(
                    intentionText: $intentionText,
                    recentIntentions: recentIntentions,
                    onStart: { intention in
                        startSessionWithIntention(intention)
                    }
                )
            } else {
                profileSelector
                modePicker
                timerDisplay
                timerOptions
                blockSummary
                cancelIntensityPicker
                startButton
                profileQuickStart
            }
        }
        .animation(.mediumEase, value: showIntentionInput)
        .onAppear {
            appState.ensureActiveProfile(in: profiles)
            if let profile = activeProfile {
                viewModel.loadFromProfile(profile)
            }
            updateBurnoutBanner()
        }
        .onChange(of: profiles.count) { _, _ in
            appState.ensureActiveProfile(in: profiles)
        }
        .onChange(of: appState.activeProfileID) { _, _ in
            if let profile = activeProfile {
                viewModel.loadFromProfile(profile)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .timerLimit)
                .environment(themeManager)
        }
    }

    private func updateBurnoutBanner() {
        let todayStart = Date().startOfDay
        let todaySeconds = allSessions
            .filter { $0.startedAt >= todayStart && $0.sessionType == "focus" }
            .reduce(0) { $0 + $1.actualDuration }
        burnoutDetector.updateBanner(
            todayFocusSeconds: todaySeconds,
            dailyLimitHours: settingsViewModel.burnoutDailyLimitHours
        )
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
            HStack(spacing: Constants.Design.spacingSM) {
                ProfileSelectorView(
                    profiles: profiles,
                    activeProfile: activeProfile,
                    onSelect: { appState.setActiveProfile($0) }
                )
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
        .padding(Constants.Design.spacingXS)
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
                    title: String(localized: "\(minutes)분"),
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

    private var sliderMaxMinutes: Int {
        licenseManager.isPro
            ? Constants.Timer.maximumMinutes
            : Constants.Subscription.freeTimerMaxMinutes
    }

    private var customSlider: some View {
        VStack(spacing: Constants.Design.spacingXS) {
            Slider(
                value: Binding(
                    get: { viewModel.customMinutes },
                    set: { viewModel.updateCustomMinutes($0) }
                ),
                in: Double(Constants.Timer.minimumMinutes)...Double(sliderMaxMinutes)
            )
            .tint(themeManager.primary)
            .accessibilityLabel("타이머 시간 설정")

            HStack {
                Text("\(Constants.Timer.minimumMinutes)분")
                Spacer()
                if !licenseManager.isPro {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 2) {
                            Text("\(sliderMaxMinutes)분")
                            ProBadge()
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("\(sliderMaxMinutes)분")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
    }

    // MARK: - 차단 요약

    @ViewBuilder
    private var blockSummary: some View {
        if !activeSites.isEmpty || !activeApps.isEmpty {
            HStack(spacing: Constants.Design.spacingMD) {
                if !activeSites.isEmpty {
                    Label(String(localized: "\(activeSites.count)개 사이트"), systemImage: "globe")
                }
                if !activeApps.isEmpty {
                    Label(String(localized: "\(activeApps.count)개 앱"), systemImage: "app.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 취소 강도

    private var cancelIntensityPicker: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingXS) {
            Text("취소 강도")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: Constants.Design.spacingSM) {
                popoverIntensityChip("기본", level: 0, proRequired: false)
                popoverIntensityChip("강함", level: 1, proRequired: true)
                popoverIntensityChip("하드코어", level: 2, proRequired: true)
            }
        }
    }

    private func popoverIntensityChip(_ title: String, level: Int, proRequired: Bool) -> some View {
        let isBlocked = proRequired && licenseManager.requiresPro(feature: .hardcoreMode)
        return HStack(spacing: 2) {
            ChipButton(
                title: title,
                isSelected: viewModel.cancelIntensity == level,
                color: themeManager.primary
            ) {
                if isBlocked { return }
                withAnimation(.quickEase) {
                    viewModel.cancelIntensity = level
                }
            }
            if isBlocked {
                ProBadge()
            }
        }
    }

    // MARK: - 시작 버튼

    private var startButton: some View {
        Button {
            if settingsViewModel.showIntentionInput {
                showIntentionInput = true
            } else {
                startSessionWithIntention(nil)
            }
        } label: {
            Label(
                LocalizedStringKey(viewModel.selectedMode == .flowmodoro ? "플로우 시작" : "집중 시작"),
                systemImage: "bolt.fill"
            )
        }
        .primaryActionStyle(color: themeManager.startButton)
        .disabled(activeProfile == nil)
        .accessibilityLabel("집중 시작")
        .accessibilityHint("타이머를 시작하고 사이트와 앱 차단을 활성화합니다")
    }

    private func startSessionWithIntention(_ intention: String?) {
        Task {
            await appState.startFocusSession(
                duration: viewModel.initialDurationSeconds,
                sites: activeSites,
                apps: activeApps,
                modelContext: modelContext,
                mode: viewModel.selectedMode.appStateMode,
                pomodoroConfiguration: viewModel.pomodoroConfiguration,
                intention: intention,
                blocklistMode: viewModel.blocklistMode,
                cancelIntensity: viewModel.cancelIntensity,
                cancelLockoutMinutes: viewModel.cancelLockoutMinutes
            )
        }
        showIntentionInput = false
        intentionText = ""
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

#Preview("유휴 상태") {
    IdleContentView()
        .environment(AppState())
        .environment(ThemeManager.shared)
        .environment(SettingsViewModel())
        .environment(LicenseManager.shared)
        .frame(width: 340)
        .padding()
}
