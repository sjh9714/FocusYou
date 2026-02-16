import SwiftUI
import SwiftData

// MARK: - 메인 대시보드 창 (v0.5 리디자인)

struct MainDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LicenseManager.self) private var licenseManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \BlockProfile.createdAt)
    private var profiles: [BlockProfile]
    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]

    @State private var quickStartMode: AppState.TimerMode = .free
    @State private var customFreeMinutes: Double = Double(Constants.Timer.presets.first ?? 25)
    @State private var selectedFreePreset: Int? = Constants.Timer.presets.first ?? 25
    @State private var pomodoroConfiguration: PomodoroConfiguration = .default
    @State private var isSessionActionInFlight = false
    @State private var showThemePicker = false
    @State private var showDashIntentionInput = false
    @State private var dashIntentionText = ""
    @State private var dashRetrospectCompleted = false
    @State private var showDashPaywall = false
    @Namespace private var dashModeNamespace

    var body: some View {
        Group {
            if settingsViewModel.hasCompletedOnboarding {
                dashboardContent
            } else {
                OnboardingView()
            }
        }
    }

    // MARK: - 대시보드 콘텐츠

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.Design.spacingXL) {
                header
                if appState.showError {
                    dashboardErrorPanel
                }
                if appState.showPrivateRelayWarning {
                    dashboardPrivateRelayPanel
                }
                heroCard
                todayStatsRow
                quickActionsBar
                recentSessionsCard
            }
            .padding(Constants.Design.spacingXL)
        }
        .background(themeManager.background)
        .animation(.quickEase, value: appState.showPrivateRelayWarning)
        .onAppear {
            appState.ensureActiveProfile(in: profiles)
        }
        .onChange(of: profiles.count) { _, _ in
            appState.ensureActiveProfile(in: profiles)
        }
        .sheet(isPresented: $showDashPaywall) {
            PaywallView(reason: .timerLimit)
                .environment(themeManager)
        }
    }

    // MARK: - 에러 패널

    private var dashboardErrorPanel: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Label("오류", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(themeManager.stopButton)

            Text(appState.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: Constants.Design.spacingSM) {
                if appState.canRetryBlockingDeactivation {
                    Button {
                        Task {
                            await appState.retryBlockingDeactivation()
                        }
                    } label: {
                        Text("다시 시도")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionStyle(color: themeManager.stopButton)
                }

                Button {
                    appState.dismissError()
                } label: {
                    Text("닫기")
                        .frame(maxWidth: .infinity)
                }
                .secondaryActionStyle(color: .secondary)
            }
        }
        .frostedCard()
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                .stroke(themeManager.stopButton.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Private Relay 경고 패널

    private var dashboardPrivateRelayPanel: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Label(
                "Private Relay가 Safari 차단을 우회 중",
                systemImage: "exclamationmark.shield.fill"
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(themeManager.warning)

            Text("iCloud Private Relay가 켜져 있어 Safari에서 웹사이트 차단이 우회됩니다. 아래 방법 중 하나를 선택하세요.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                Label {
                    Text("Chrome, Firefox 등에서는 정상 차단됩니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                }

                Button {
                    appState.openPrivateRelaySettings()
                } label: {
                    Label("Private Relay 설정 열기", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .primaryActionStyle(color: themeManager.warning)
            }

            Button {
                appState.dismissPrivateRelayWarning()
            } label: {
                Text("닫기")
                    .frame(maxWidth: .infinity)
            }
            .secondaryActionStyle(color: .secondary)
        }
        .frostedCard()
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                .stroke(themeManager.warning.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Constants.Design.spacingXS) {
                Text("Focus You Dashboard")
                    .font(.title2.bold())
                Text("집중 세션 관리 및 통계")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: Constants.Design.spacingSM) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
            .padding(.horizontal, Constants.Design.spacingMD)
            .padding(.vertical, Constants.Design.spacingSM)
            .background(statusColor.opacity(0.08), in: Capsule())
        }
    }

    // MARK: - 히어로 카드 (상태별)

    private var heroCard: some View {
        Group {
            switch appState.focusState {
            case .idle:
                idleHero
            case .focusing, .paused:
                activeHero
            case .completed:
                completedHero
            }
        }
        .animation(.mediumEase, value: appState.focusState)
    }

    // 유휴 → 빠른 시작 CTA
    private var idleHero: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingLG) {
            HStack(spacing: Constants.Design.spacingSM) {
                IconBadge(systemName: "bolt.fill", color: themeManager.primary, size: 36)
                Text("새 세션 시작")
                    .font(.headline)
            }

            activeProfilePicker

            // 모드 피커
            HStack(spacing: 4) {
                SegmentedPill(
                    title: "자유",
                    tag: AppState.TimerMode.free,
                    selection: $quickStartMode,
                    namespace: dashModeNamespace,
                    activeColor: themeManager.primary
                )
                SegmentedPill(
                    title: "뽀모도로",
                    tag: AppState.TimerMode.pomodoro,
                    selection: $quickStartMode,
                    namespace: dashModeNamespace,
                    activeColor: themeManager.primary
                )
                SegmentedPill(
                    title: "플로우",
                    tag: AppState.TimerMode.flowmodoro,
                    selection: $quickStartMode,
                    namespace: dashModeNamespace,
                    activeColor: themeManager.primary
                )
            }
            .padding(Constants.Design.spacingXS)
            .background(Color.secondary.opacity(0.06), in: Capsule())

            switch quickStartMode {
            case .free:
                freeTimerConfig
            case .pomodoro:
                pomodoroTimerConfig
            case .flowmodoro:
                flowmodoroConfig
            }

            HStack(spacing: Constants.Design.spacingMD) {
                Label("\(activeSites.count)개 사이트", systemImage: "globe")
                Label("\(activeApps.count)개 앱", systemImage: "app.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)

            if showDashIntentionInput {
                dashIntentionInputSection
            } else {
                Button {
                    if settingsViewModel.showIntentionInput {
                        showDashIntentionInput = true
                    } else {
                        startSessionFromDashboard(intention: nil)
                    }
                } label: {
                    Label(startButtonTitle, systemImage: "bolt.fill")
                }
                .primaryActionStyle(color: themeManager.startButton)
                .disabled(isSessionActionInFlight || activeProfile == nil)
            }
        }
        .frostedCard()
        .animation(.mediumEase, value: showDashIntentionInput)
    }

    private var dashIntentionInputSection: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            HStack(spacing: Constants.Design.spacingSM) {
                Image(systemName: "target")
                    .foregroundStyle(themeManager.primary)
                Text("이번 세션의 의도")
                    .font(.callout.weight(.medium))
            }

            TextField("무엇에 집중할까요?", text: $dashIntentionText)
                .textFieldStyle(.plain)
                .font(.callout)
                .padding(Constants.Design.spacingMD)
                .background(
                    Color.secondary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                )
                .onSubmit {
                    let trimmed = dashIntentionText.trimmingCharacters(in: .whitespacesAndNewlines)
                    startSessionFromDashboard(intention: trimmed.isEmpty ? nil : trimmed)
                }

            Button {
                let trimmed = dashIntentionText.trimmingCharacters(in: .whitespacesAndNewlines)
                startSessionFromDashboard(intention: trimmed.isEmpty ? nil : trimmed)
            } label: {
                Label("집중 시작", systemImage: "bolt.fill")
            }
            .primaryActionStyle(color: themeManager.startButton)
            .disabled(isSessionActionInFlight)
        }
    }

    private var activeProfilePicker: some View {
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

    // MARK: - 자유 모드 설정

    private var selectedDurationMinutes: Int {
        selectedFreePreset ?? Int(customFreeMinutes)
    }

    private var freeTimerConfig: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            // 큰 시간 표시
            Text(TimeInterval(selectedDurationMinutes * 60).formattedAsTimer)
                .font(.system(size: 36, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(themeManager.primary)
                .contentTransition(.numericText())

            // 프리셋 칩
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

            // 커스텀 슬라이더
            VStack(spacing: Constants.Design.spacingXS) {
                let dashSliderMax = licenseManager.isPro
                    ? Constants.Timer.maximumMinutes
                    : Constants.Subscription.freeTimerMaxMinutes

                Slider(
                    value: $customFreeMinutes,
                    in: Double(Constants.Timer.minimumMinutes)...Double(dashSliderMax)
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
                            showDashPaywall = true
                        } label: {
                            HStack(spacing: 2) {
                                Text("\(dashSliderMax)분")
                                ProBadge()
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("\(dashSliderMax)분")
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
            // 큰 시간 표시 (집중 시간)
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

    // 진행 중 → 라이브 타이머
    private var activeHero: some View {
        HStack(spacing: Constants.Design.spacingXL) {
            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                Text(statusTitle)
                    .font(.headline)

                Text(statusDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

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

                HStack(spacing: Constants.Design.spacingSM) {
                    if isDashFlowmodoroFocus {
                        Button {
                            finishFlowmodoroFromDashboard()
                        } label: {
                            Label("집중 완료", systemImage: "checkmark.circle.fill")
                        }
                        .primaryActionStyle(color: themeManager.primary)
                        .disabled(isSessionActionInFlight)

                        Button {
                            stopSessionFromDashboard()
                        } label: {
                            Label("취소", systemImage: "xmark")
                        }
                        .secondaryActionStyle(color: themeManager.stopButton)
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

                        Button {
                            stopSessionFromDashboard()
                        } label: {
                            Label("중지", systemImage: "stop.fill")
                        }
                        .secondaryActionStyle(color: themeManager.stopButton)
                        .disabled(isSessionActionInFlight)
                    }
                }
            }

            Spacer()

            VStack(spacing: Constants.Design.spacingXS) {
                Text(remainingTimerText)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(themeManager.primary)

                Text(isDashFlowmodoroFocus ? "경과 시간" : "남은 시간")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frostedCard()
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                .stroke(themeManager.primary.opacity(0.15), lineWidth: 0.5)
        )
    }

    // 완료 → 축하
    private var completedHero: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            HStack(spacing: Constants.Design.spacingLG) {
                IconBadge(systemName: "checkmark.circle.fill", color: themeManager.completed, size: 44)

                VStack(alignment: .leading, spacing: Constants.Design.spacingXS) {
                    HStack(spacing: Constants.Design.spacingSM) {
                        Text("세션 완료!")
                            .font(.headline)
                        if let emoji = appState.completedSession?.retrospectEmoji {
                            Text(emoji)
                        }
                        if currentStreakDays > 0 {
                            Text("\(currentStreakDays)일 연속")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(themeManager.warning)
                        }
                    }
                    if let intention = appState.lastCompletedIntention, !intention.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption2)
                            Text(intention)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(themeManager.accent)
                    }
                    Text(appState.completedSummaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    appState.resetToIdle()
                    dashRetrospectCompleted = false
                } label: {
                    Label("확인", systemImage: "checkmark")
                }
                .primaryActionStyle(color: themeManager.primary)
                .frame(width: 100)
            }

            if settingsViewModel.showRetrospect && !dashRetrospectCompleted {
                RetrospectView(
                    level: settingsViewModel.retrospectLevel,
                    onComplete: { data in
                        appState.saveRetrospectFull(
                            emoji: data.emoji,
                            text: data.text,
                            rating: data.rating
                        )
                        dashRetrospectCompleted = true
                    },
                    onSkip: {
                        dashRetrospectCompleted = true
                    }
                )
            }
        }
        .frostedCard()
    }

    // MARK: - 오늘 통계

    private var todayStatsRow: some View {
        HStack(spacing: Constants.Design.spacingMD) {
            statCard(
                icon: "timer",
                color: themeManager.primary,
                value: TimeInterval(todayFocusedSeconds).formattedAsReadable,
                label: "오늘 집중 시간"
            )
            statCard(
                icon: "chart.bar.fill",
                color: themeManager.secondary,
                value: String(localized: "\(todayCompletedPomodoroCount)회"),
                label: "완료한 뽀모도로"
            )
            statCard(
                icon: "checkmark.seal.fill",
                color: themeManager.accent,
                value: "\(todayCompletionRate)%",
                label: "세션 완료율"
            )
            statCard(
                icon: "flame.fill",
                color: themeManager.warning,
                value: String(localized: "\(currentStreakDays)일"),
                label: "연속 집중"
            )
        }
    }

    private func statCard(
        icon: String,
        color: Color,
        value: String,
        label: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            IconBadge(systemName: icon, color: color, size: 32)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)

            Text(LocalizedStringKey(label))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedCard()
    }

    // MARK: - 퀵 액션 바

    private var quickActionsBar: some View {
        HStack(spacing: Constants.Design.spacingMD) {
            dashboardAction(title: "차단 목록", symbol: "list.bullet.rectangle", tint: themeManager.primary) {
                openWindow(id: "block-list")
            }
            dashboardAction(title: "설정", symbol: "gearshape", tint: themeManager.accent) {
                openWindow(id: "settings")
            }

            // 테마 퀵 피커
            Button {
                showThemePicker.toggle()
            } label: {
                HStack(spacing: Constants.Design.spacingSM) {
                    Text(themeManager.selectedTheme.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Circle().fill(themeManager.primary).frame(width: 10, height: 10)
                        Circle().fill(themeManager.secondary).frame(width: 10, height: 10)
                        Circle().fill(themeManager.accent).frame(width: 10, height: 10)
                    }

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
            .popover(isPresented: $showThemePicker) {
                themePickerPopover
            }
        }
    }

    private func dashboardAction(
        title: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(LocalizedStringKey(title), systemImage: symbol)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .secondaryActionStyle(color: tint)
    }

    // MARK: - 테마 피커 팝오버

    private var themePickerPopover: some View {
        VStack(spacing: 0) {
            Text("테마 선택")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Constants.Design.spacingMD)
                .padding(.vertical, Constants.Design.spacingSM)

            Rectangle().fill(.quaternary).frame(height: 0.5)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(themeManager.availableThemes) { theme in
                        let isSelected = theme.id == themeManager.selectedThemeID

                        Button {
                            withAnimation(.quickEase) {
                                themeManager.selectTheme(id: theme.id)
                            }
                        } label: {
                            HStack(spacing: Constants.Design.spacingSM) {
                                HStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: theme.primaryHex))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: theme.secondaryHex))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: theme.accentHex))
                                }
                                .frame(width: 40, height: 12)
                                .clipShape(RoundedRectangle(cornerRadius: 3))

                                Text(theme.name)
                                    .font(.callout)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color(hex: theme.primaryHex))
                                }
                            }
                            .padding(.horizontal, Constants.Design.spacingMD)
                            .padding(.vertical, Constants.Design.spacingSM)
                            .background(
                                isSelected
                                    ? Color(hex: theme.primaryHex).opacity(0.06)
                                    : Color.clear
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 220, height: 340)
    }

    // MARK: - 최근 세션 (테이블)

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Text("오늘 세션")
                .font(.headline)

            if todaySessions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: Constants.Design.spacingSM) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("아직 기록된 세션이 없습니다.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Constants.Design.spacingXL)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(todaySessions.prefix(8).enumerated()), id: \.element.id) { index, session in
                        sessionRow(session, isEven: index.isMultiple(of: 2))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerMD))
            }
        }
        .frostedCard()
    }

    private func sessionRow(_ session: FocusSession, isEven: Bool) -> some View {
        HStack(spacing: Constants.Design.spacingMD) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(session.timerMode == "pomodoro" ? "뽀모도로" : session.timerMode == "flowmodoro" ? "플로우" : "자유"))
                    .font(.callout.weight(.medium))

                if let intention = session.intention, !intention.isEmpty {
                    Text(intention)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let emoji = session.retrospectEmoji {
                Text(emoji)
                    .font(.caption)
            }

            Text(TimeInterval(session.actualDuration).formattedAsReadable)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(LocalizedStringKey(session.wasCompleted ? "완료" : "중지"))
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    session.wasCompleted
                        ? themeManager.secondary.opacity(0.12)
                        : themeManager.stopButton.opacity(0.1)
                )
                .foregroundStyle(
                    session.wasCompleted ? themeManager.secondary : themeManager.stopButton
                )
                .clipShape(Capsule())
        }
        .padding(.horizontal, Constants.Design.spacingMD)
        .padding(.vertical, Constants.Design.spacingSM)
        .background(isEven ? Color.secondary.opacity(0.03) : Color.clear)
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

    private var todaySessions: [FocusSession] {
        let start = Date().startOfDay
        return sessions.filter { $0.startedAt >= start }
    }

    private var todayFocusedSeconds: Int {
        todaySessions.reduce(0) { $0 + $1.actualDuration }
    }

    private var todayCompletedPomodoroCount: Int {
        todaySessions.filter { $0.timerMode == "pomodoro" && $0.wasCompleted }.count
    }

    private var todayCompletionRate: Int {
        guard !todaySessions.isEmpty else { return 0 }
        let completed = todaySessions.filter(\.wasCompleted).count
        return Int((Double(completed) / Double(todaySessions.count)) * 100)
    }

    private var currentStreakDays: Int {
        StreakCalculator.calculate(from: sessions).current
    }

    // MARK: - 세션 액션

    private func startSessionFromDashboard(intention: String? = nil) {
        guard !isSessionActionInFlight else { return }
        isSessionActionInFlight = true

        let selectedDuration: TimeInterval
        switch quickStartMode {
        case .free:
            selectedDuration = TimeInterval(selectedDurationMinutes * 60)
        case .pomodoro:
            selectedDuration = TimeInterval(pomodoroConfiguration.focusMinutes * 60)
        case .flowmodoro:
            selectedDuration = Constants.Timer.flowmodoroMaxDuration
        }

        Task { @MainActor in
            await appState.startFocusSession(
                duration: selectedDuration,
                sites: activeSites,
                apps: activeApps,
                modelContext: modelContext,
                mode: quickStartMode,
                pomodoroConfiguration: pomodoroConfiguration,
                intention: intention
            )
            isSessionActionInFlight = false
            showDashIntentionInput = false
            dashIntentionText = ""
        }
    }

    private func finishFlowmodoroFromDashboard() {
        guard !isSessionActionInFlight else { return }
        isSessionActionInFlight = true

        Task { @MainActor in
            await appState.finishFlowmodoroFocus(modelContext: modelContext)
            isSessionActionInFlight = false
        }
    }

    private func stopSessionFromDashboard() {
        guard !isSessionActionInFlight else { return }
        isSessionActionInFlight = true

        Task { @MainActor in
            await appState.stopSession(modelContext: modelContext)
            isSessionActionInFlight = false
        }
    }

    // MARK: - 상태 텍스트

    private var statusTitle: String {
        switch appState.focusState {
        case .idle: return String(localized: "대기 중")
        case .focusing:
            if appState.timerMode == .flowmodoro {
                let isBreak = appState.currentFlowmodoroPhase == .rest
                return isBreak ? String(localized: "플로우 휴식 중") : String(localized: "플로우 진행 중")
            }
            return appState.timerMode == .pomodoro ? String(localized: "뽀모도로 진행 중") : String(localized: "집중 진행 중")
        case .paused: return String(localized: "일시정지")
        case .completed: return String(localized: "세션 완료")
        }
    }

    private var statusDetailText: String {
        switch appState.focusState {
        case .idle: return String(localized: "새 집중 세션을 시작해보세요")
        case .focusing, .paused:
            if appState.timerMode == .pomodoro {
                return "\(appState.pomodoroPhaseTitle) · \(appState.pomodoroCycleProgressText)"
            }
            if appState.timerMode == .flowmodoro {
                let isBreak = appState.currentFlowmodoroPhase == .rest
                return isBreak ? String(localized: "휴식 카운트다운") : String(localized: "플로우모도로")
            }
            return String(localized: "자유 타이머")
        case .completed: return appState.completedSummaryText
        }
    }

    private var remainingTimerText: String {
        switch appState.focusState {
        case .focusing, .paused:
            if isDashFlowmodoroFocus {
                return "▲ \(appState.timer.elapsedTime.formattedAsTimer)"
            }
            return appState.timer.remainingTime.formattedAsTimer
        case .idle: return "00:00"
        case .completed: return "DONE"
        }
    }

    private var isDashFlowmodoroFocus: Bool {
        appState.timerMode == .flowmodoro && appState.currentFlowmodoroPhase == .focus
    }

    private var statusColor: Color {
        switch appState.focusState {
        case .idle: return .secondary
        case .focusing: return themeManager.primary
        case .paused: return themeManager.pauseButton
        case .completed: return themeManager.completed
        }
    }
}

#Preview {
    MainDashboardView()
        .environment(AppState())
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .environment(LicenseManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
        .frame(width: 820, height: 620)
}
