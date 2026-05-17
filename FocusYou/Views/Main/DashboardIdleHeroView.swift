import SwiftUI
import SwiftData

// MARK: - 대시보드 유휴 히어로 카드

struct DashboardIdleHeroView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LicenseManager.self) private var licenseManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \BlockProfile.createdAt)
    private var profiles: [BlockProfile]

    @State private var quickStartMode: AppState.TimerMode = .free
    @State private var customFreeMinutes: Double = Double(Constants.Timer.presets.first ?? 25)
    @State private var selectedFreePreset: Int? = Constants.Timer.presets.first ?? 25
    @State private var pomodoroConfiguration: PomodoroConfiguration = .default
    @State private var cancelIntensity: Int = 0
    @State private var cancelLockoutMinutes: Int = 5
    @State private var blocklistMode: String = "blocklist"
    @State private var isSessionActionInFlight = false
    @State private var showIntentionInput = false
    @State private var intentionText = ""
    @State private var showPaywall = false
    @State private var showCustomize = false
    @State private var showAdvancedControls = false
    @State private var pendingStartAction: PendingStartAction = .primary25
    @Namespace private var modeNamespace

    private enum PendingStartAction {
        case primary25
        case custom
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingLG) {
            if let rejoinInfo = appState.pendingScheduleRejoin {
                scheduleRejoinBanner(rejoinInfo)
            }

            primaryStartSection
            blockingReadinessRow
            customizationSection

            if showIntentionInput {
                intentionInputSection
            }
        }
        .frostedCard()
        .animation(.mediumEase, value: showIntentionInput)
        .animation(.mediumEase, value: showCustomize)
        .animation(.mediumEase, value: showAdvancedControls)
        .onAppear { loadProfileTimerSettings() }
        .onChange(of: appState.activeProfileID) { _, _ in loadProfileTimerSettings() }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .timerLimit)
                .environment(themeManager)
        }
    }

    // MARK: - 25분 기본 시작

    private var primaryStartSection: some View {
        HStack(alignment: .center, spacing: Constants.Design.spacingXL) {
            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                HStack(spacing: Constants.Design.spacingSM) {
                    IconBadge(systemName: "bolt.fill", color: themeManager.primary, size: 36)
                    Text("25분 집중")
                        .font(.headline)
                }

                Text("가장 빠른 시작입니다. 세부 모드와 시간은 커스터마이즈에서 바꿀 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(TimeInterval(25 * 60).formattedAsTimer)
                .font(.system(size: 42, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(themeManager.primary)

            Button {
                beginStart(.primary25)
            } label: {
                Label(primaryStartButtonTitle, systemImage: "play.fill")
            }
            .primaryActionStyle(color: themeManager.startButton)
            .disabled(isSessionActionInFlight || activeProfile == nil)
            .frame(width: 190)
        }
    }

    private var primaryStartButtonTitle: String {
        hasBlockingTargets ? String(localized: "25분 집중 시작") : String(localized: "25분 타이머 시작")
    }

    // MARK: - 차단 준비 상태

    private var blockingReadinessRow: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingXS) {
            Label(blockingReadinessTitle, systemImage: hasBlockingTargets ? "checkmark.shield.fill" : "timer")
                .font(.callout.weight(.semibold))
                .foregroundStyle(hasBlockingTargets ? themeManager.primary : .secondary)

            Text(blockingReadinessDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Constants.Design.spacingMD)
        .background(
            (hasBlockingTargets ? themeManager.primary : Color.secondary).opacity(0.06),
            in: RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
        )
    }

    private var blockingReadinessTitle: String {
        hasBlockingTargets
            ? String(localized: "차단 활성 준비")
            : String(localized: "타이머만 실행")
    }

    private var blockingReadinessDetail: String {
        if hasBlockingTargets {
            if PersistedBlocklistMode(storedValue: blocklistMode) == .allowlist,
               activeSites.isEmpty,
               activeApps.isEmpty {
                return String(localized: "허용 목록 모드입니다. 비어 있는 허용 목록은 알려진 방해 사이트를 차단합니다.")
            }

            let countText = String(
                format: String(localized: "%d개 사이트 · %d개 앱"),
                activeSites.count,
                activeApps.count
            )
            if Constants.Distribution.isAppStoreBuild {
                return countText + " " + String(localized: "차단 예정. 첫 차단 세션 전 macOS Network Extension 승인이 필요합니다.")
            }
            return countText + " " + String(localized: "차단 예정. 세션 시작 시 차단이 활성화됩니다.")
        }

        return String(localized: "차단 대상이 없어서 세션은 기록과 타이머만 실행합니다.")
    }

    private var hasBlockingTargets: Bool {
        PersistedBlocklistMode(storedValue: blocklistMode).hasBlockingTargets(
            domains: activeSites.map(\.domain),
            appBundleIds: activeApps.map(\.bundleId)
        )
    }

    // MARK: - 커스터마이즈

    private var customizationSection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            DisclosureGroup(isExpanded: $showCustomize) {
                VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
                    profilePicker
                    modePicker

                    switch quickStartMode {
                    case .free:
                        freeTimerConfig
                    case .pomodoro:
                        pomodoroTimerConfig
                    case .flowmodoro:
                        flowmodoroConfig
                    }

                    if !showIntentionInput {
                        Button {
                            beginStart(.custom)
                        } label: {
                            Label(startButtonTitle, systemImage: "bolt.fill")
                        }
                        .secondaryActionStyle(color: themeManager.startButton)
                        .disabled(isSessionActionInFlight || activeProfile == nil)
                    }

                    DisclosureGroup(isExpanded: $showAdvancedControls) {
                        cancelIntensityPicker
                    } label: {
                        Label("고급 컨트롤", systemImage: "slider.horizontal.3")
                            .font(.caption.weight(.semibold))
                    }
                }
                .padding(.top, Constants.Design.spacingSM)
            } label: {
                Label("커스터마이즈", systemImage: "slider.horizontal.2.square")
                    .font(.callout.weight(.semibold))
            }
        }
    }

    // MARK: - 의도 입력

    private var intentionInputSection: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            HStack(spacing: Constants.Design.spacingSM) {
                Image(systemName: "target")
                    .foregroundStyle(themeManager.primary)
                Text("이번 세션의 의도")
                    .font(.callout.weight(.medium))
            }

            TextField("무엇에 집중할까요?", text: $intentionText)
                .textFieldStyle(.plain)
                .font(.callout)
                .padding(Constants.Design.spacingMD)
                .background(
                    Color.secondary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                )
                .onSubmit {
                    let trimmed = intentionText.trimmingCharacters(in: .whitespacesAndNewlines)
                    startSession(intention: trimmed.isEmpty ? nil : trimmed, action: pendingStartAction)
                }

            Button {
                let trimmed = intentionText.trimmingCharacters(in: .whitespacesAndNewlines)
                startSession(intention: trimmed.isEmpty ? nil : trimmed, action: pendingStartAction)
            } label: {
                Label("집중 시작", systemImage: "bolt.fill")
            }
            .primaryActionStyle(color: themeManager.startButton)
            .disabled(isSessionActionInFlight)
        }
    }

    // MARK: - 프로필 피커

    private var profilePicker: some View {
        HStack(spacing: Constants.Design.spacingSM) {
            ForEach(profiles) { profile in
                let isActive = profile.persistentModelID == activeProfile?.persistentModelID

                Button {
                    appState.setActiveProfile(profile)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: profile.icon)
                            .font(.caption)
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
                .accessibilityLabel("\(profile.name) 프로필 선택")
            }

            Button {
                openWindow(id: "profiles")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, Constants.Design.spacingSM)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08), in: Capsule())
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("프로필 추가")
        }
    }

    // MARK: - 모드 피커

    private var modePicker: some View {
        HStack(spacing: 4) {
            SegmentedPill(
                title: "자유",
                tag: AppState.TimerMode.free,
                selection: $quickStartMode,
                namespace: modeNamespace,
                activeColor: themeManager.primary
            )
            SegmentedPill(
                title: "뽀모도로",
                tag: AppState.TimerMode.pomodoro,
                selection: $quickStartMode,
                namespace: modeNamespace,
                activeColor: themeManager.primary
            )
            SegmentedPill(
                title: "플로우",
                tag: AppState.TimerMode.flowmodoro,
                selection: $quickStartMode,
                namespace: modeNamespace,
                activeColor: themeManager.primary
            )
        }
        .padding(Constants.Design.spacingXS)
        .background(Color.secondary.opacity(0.06), in: Capsule())
    }

    // MARK: - 자유 모드 설정

    private var selectedDurationMinutes: Int {
        selectedFreePreset ?? Int(customFreeMinutes)
    }

    private var freeTimerConfig: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            Text(TimeInterval(selectedDurationMinutes * 60).formattedAsTimer)
                .font(.system(size: 36, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(themeManager.primary)
                .contentTransition(.numericText())

            HStack(spacing: Constants.Design.spacingSM) {
                ForEach(Constants.Timer.presets, id: \.self) { minutes in
                    ChipButton(
                        title: String(localized: "\(minutes)분"),
                        isSelected: selectedFreePreset == minutes,
                        color: themeManager.primary
                    ) {
                        selectedFreePreset = minutes
                        customFreeMinutes = Double(minutes)
                    }
                }
            }

            VStack(spacing: Constants.Design.spacingXS) {
                let sliderMax = licenseManager.isPro
                    ? Constants.Timer.maximumMinutes
                    : Constants.Subscription.freeTimerMaxMinutes

                Slider(
                    value: $customFreeMinutes,
                    in: Double(Constants.Timer.minimumMinutes)...Double(sliderMax)
                )
                .tint(themeManager.primary)
                .onChange(of: customFreeMinutes) { _, newValue in
                    customFreeMinutes = newValue.rounded()
                    let rounded = Int(customFreeMinutes)
                    if Constants.Timer.presets.contains(rounded) {
                        selectedFreePreset = rounded
                    } else {
                        selectedFreePreset = nil
                    }
                }

                HStack {
                    Text("\(Constants.Timer.minimumMinutes)분")
                    Spacer()
                    if !licenseManager.isPro {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 2) {
                                Text("\(sliderMax)분")
                                ProBadge()
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("\(sliderMax)분")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .animation(.quickEase, value: selectedDurationMinutes)
    }

    // MARK: - 뽀모도로 설정

    private var pomodoroTimerConfig: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            Text(TimeInterval(pomodoroConfiguration.focusMinutes * 60).formattedAsTimer)
                .font(.system(size: 36, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(themeManager.primary)
                .contentTransition(.numericText())

            PomodoroConfigView(configuration: $pomodoroConfiguration)
        }
        .animation(.quickEase, value: pomodoroConfiguration.focusMinutes)
    }

    // MARK: - 플로우모도로 설정

    private var flowmodoroConfig: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            Image(systemName: "infinity")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(themeManager.primary)

            VStack(spacing: Constants.Design.spacingSM) {
                Text("원하는 만큼 집중하세요")
                    .font(.callout.weight(.medium))
                Text("집중 시간의 1/5이 휴식으로 자동 부여됩니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 취소 강도

    private var cancelIntensityPicker: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingXS) {
            Text("취소 강도")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: Constants.Design.spacingSM) {
                intensityChip("기본", level: 0, proRequired: false)
                intensityChip("강함", level: 1, proRequired: true)
                intensityChip("하드코어", level: 2, proRequired: true)
            }
        }
    }

    private func intensityChip(_ title: String, level: Int, proRequired: Bool) -> some View {
        let isBlocked = proRequired && licenseManager.requiresPro(feature: .hardcoreMode)
        return HStack(spacing: 2) {
            ChipButton(
                title: title,
                isSelected: cancelIntensity == level,
                color: themeManager.primary
            ) {
                if isBlocked { return }
                withAnimation(.quickEase) {
                    cancelIntensity = level
                }
            }
            if isBlocked {
                ProBadge()
            }
        }
    }

    private var startButtonTitle: String {
        switch quickStartMode {
        case .free:
            return String(localized: "\(selectedDurationMinutes)분 집중 시작")
        case .pomodoro:
            return String(localized: "뽀모도로 시작")
        case .flowmodoro:
            return String(localized: "플로우 시작")
        }
    }

    // MARK: - 스케줄 재참여 배너

    private func scheduleRejoinBanner(_ info: AppState.PendingScheduleInfo) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
                .foregroundStyle(themeManager.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(info.scheduleName)
                    .font(.callout.weight(.semibold))
                Text("\(info.endTimeFormatted)까지 진행 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await appState.rejoinPendingSchedule(modelContext: modelContext)
                }
            } label: {
                Label("참여하기", systemImage: "play.fill")
            }
            .primaryActionStyle(color: themeManager.accent)
            .frame(width: 120)
        }
        .padding(Constants.Design.spacingMD)
        .background(themeManager.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerMD))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                .stroke(themeManager.accent.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - 데이터

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

    // MARK: - 프로필 동기화

    private func loadProfileTimerSettings() {
        guard let profile = activeProfile else { return }
        quickStartMode = AppState.TimerMode(rawValue: profile.timerMode) ?? .free
        let focusMinutes = profile.focusDuration / 60
        selectedFreePreset = Constants.Timer.presets.contains(focusMinutes) ? focusMinutes : nil
        customFreeMinutes = Double(focusMinutes)
        pomodoroConfiguration = PomodoroConfiguration(
            focusMinutes: focusMinutes,
            shortBreakMinutes: profile.breakDuration / 60,
            longBreakMinutes: profile.longBreakDuration / 60,
            cycles: profile.pomodoroCount
        )
        cancelIntensity = profile.cancelIntensity ?? 0
        cancelLockoutMinutes = profile.cancelLockoutMinutes ?? 5
        blocklistMode = profile.blocklistMode ?? "blocklist"
    }

    // MARK: - 세션 시작

    private func beginStart(_ action: PendingStartAction) {
        pendingStartAction = action
        if settingsViewModel.showIntentionInput {
            showIntentionInput = true
        } else {
            startSession(intention: nil, action: action)
        }
    }

    private func startSession(intention: String? = nil, action: PendingStartAction) {
        guard !isSessionActionInFlight else { return }
        isSessionActionInFlight = true

        let selectedDuration: TimeInterval
        let selectedMode: AppState.TimerMode
        let selectedPomodoroConfiguration: PomodoroConfiguration

        switch action {
        case .primary25:
            selectedDuration = TimeInterval(25 * 60)
            selectedMode = .free
            selectedPomodoroConfiguration = .default
        case .custom:
            selectedMode = quickStartMode
            selectedPomodoroConfiguration = pomodoroConfiguration
            switch quickStartMode {
            case .free:
                selectedDuration = TimeInterval(selectedDurationMinutes * 60)
            case .pomodoro:
                selectedDuration = TimeInterval(pomodoroConfiguration.focusMinutes * 60)
            case .flowmodoro:
                selectedDuration = Constants.Timer.flowmodoroMaxDuration
            }
        }

        Task { @MainActor in
            await appState.startFocusSession(
                duration: selectedDuration,
                sites: activeSites,
                apps: activeApps,
                modelContext: modelContext,
                mode: selectedMode,
                pomodoroConfiguration: selectedPomodoroConfiguration,
                intention: intention,
                blocklistMode: blocklistMode,
                cancelIntensity: cancelIntensity,
                cancelLockoutMinutes: cancelLockoutMinutes
            )
            isSessionActionInFlight = false
            showIntentionInput = false
            intentionText = ""
        }
    }
}

#Preview {
    DashboardIdleHeroView()
        .environment(AppState())
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .environment(LicenseManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
        .padding()
}
