import SwiftUI

// MARK: - 설정 뷰 (v0.5 리디자인)

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LicenseManager.self) private var licenseManager

    @State private var showPaywall = false
    @State private var paywallReason: PaywallReason = .proFeature(.unlimitedBlocks)
    @State private var expandedThemeCategory: String?
    @State private var showRestartAlert = false

    var body: some View {
        TabView {
            // 탭 1: 일반
            Form {
                subscriptionSection
                generalSection
                themeSection
                infoSection
            }
            .formStyle(.grouped)
            .tabItem { Label("일반", systemImage: "gearshape") }

            // 탭 2: 집중
            Form {
                focusExperienceSection
                burnoutSection
            }
            .formStyle(.grouped)
            .tabItem { Label("집중", systemImage: "brain.head.profile") }

            // 탭 3: 연동
            Form {
                focusModeSection
                calendarSection
                scheduleSection
            }
            .formStyle(.grouped)
            .tabItem { Label("연동", systemImage: "link") }

            // 탭 4: 고급
            Form {
                blockingStrategySection
                diagnosticsSection
                #if DEBUG
                debugSection
                #endif
            }
            .formStyle(.grouped)
            .tabItem { Label("고급", systemImage: "wrench.and.screwdriver") }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: paywallReason)
                .environment(themeManager)
        }
        .alert("언어 변경", isPresented: $showRestartAlert) {
            Button("앱 재시작") {
                relaunchApp()
            }
            Button("나중에", role: .cancel) {}
        } message: {
            Text("언어 변경을 적용하려면 앱을 재시작해야 합니다.")
        }
    }

    // MARK: - 구독 (v2.0)

    @State private var isRestoring = false
    @State private var restoreMessage: String?

    private var subscriptionSection: some View {
        Section("구독") {
            HStack {
                VStack(alignment: .leading, spacing: Constants.Design.spacingXS) {
                    HStack(spacing: Constants.Design.spacingSM) {
                        Text(LocalizedStringKey(licenseManager.isPro ? "Pro" : "무료"))
                            .font(.callout.bold())
                        if licenseManager.isPro {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(themeManager.primary)
                        }
                    }
                    Text(LocalizedStringKey(licenseManager.isPro
                         ? "모든 기능을 사용 중입니다."
                         : "일부 기능이 제한됩니다."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !licenseManager.isPro {
                    Button {
                        paywallReason = .proFeature(.unlimitedBlocks)
                        showPaywall = true
                    } label: {
                        Label("업그레이드", systemImage: "crown.fill")
                    }
                    .secondaryActionStyle(color: themeManager.primary)
                }
            }

            // 구매 복원 버튼
            if !licenseManager.isPro {
                Button {
                    Task { await restorePurchases() }
                } label: {
                    if isRestoring {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(String(localized: "subscription_restore"))
                    }
                }
                .disabled(isRestoring)
            }

            if let restoreMessage {
                Text(restoreMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func restorePurchases() async {
        isRestoring = true
        restoreMessage = nil

        do {
            try await SubscriptionManager.shared.restorePurchases()
            let purchased = await SubscriptionManager.shared.purchasedProductIDs
            if purchased.isEmpty {
                restoreMessage = String(localized: "subscription_restore_no_purchases")
            } else {
                restoreMessage = String(localized: "subscription_restore_success")
            }
        } catch {
            restoreMessage = String(localized: "subscription_purchase_error \(error.localizedDescription)")
        }

        isRestoring = false
    }

    // MARK: - 일반

    private var generalSection: some View {
        Section("일반") {
            Picker("언어", selection: Binding(
                get: { viewModel.appLanguage },
                set: { newValue in
                    viewModel.appLanguage = newValue
                    showRestartAlert = true
                }
            )) {
                Text("시스템 언어").tag("system")
                Text("한국어").tag("ko")
                Text("English").tag("en")
            }

            Picker("외관", selection: Bindable(viewModel).appearanceMode) {
                Text("시스템").tag("system")
                Text("라이트").tag("light")
                Text("다크").tag("dark")
            }

            Toggle(
                "메뉴바에 남은 시간 표시",
                isOn: Bindable(viewModel).showMenuBarTime
            )

            Toggle(
                "완료 시 사운드 재생",
                isOn: Bindable(viewModel).playCompletionSound
            )

            Toggle(
                "차단된 앱 알림",
                isOn: Bindable(viewModel).showBlockedAppNotification
            )

            Toggle(
                "로그인 시 자동 시작",
                isOn: Bindable(viewModel).launchAtLogin
            )
        }
    }

    // MARK: - 집중 경험

    private var focusExperienceSection: some View {
        Section("집중 경험") {
            proGatedToggle(
                "의도 입력",
                isOn: Bindable(viewModel).showIntentionInput,
                feature: .intentionInput
            )
            Text("세션 시작 전 집중할 내용을 입력합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            proGatedToggle(
                "동기부여 명언",
                isOn: Bindable(viewModel).showMotivationQuotes,
                feature: .motivationQuotes
            )
            Text("집중 중과 완료 화면에 동기부여 명언을 표시합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            proGatedToggle(
                "회고",
                isOn: Bindable(viewModel).showRetrospect,
                feature: .retrospect
            )
            Text("세션 완료 후 간단한 회고를 기록합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.showRetrospect {
                Picker("회고 레벨", selection: Bindable(viewModel).retrospectLevel) {
                    ForEach(1...3, id: \.self) { level in
                        Text(Constants.Retrospect.levelNames[level - 1])
                            .tag(level)
                    }
                }
            }
        }
    }

    // MARK: - 정보

    private var infoSection: some View {
        Section("정보") {
            LabeledContent("버전", value: appVersionText)
            LabeledContent("개발", value: "Focus You")
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    // MARK: - 테마 섹션

    private var themeSection: some View {
        Section("테마") {
            ForEach(themeManager.themesByCategory, id: \.category) { group in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedThemeCategory == group.category },
                        set: { expandedThemeCategory = $0 ? group.category : nil }
                    )
                ) {
                    ForEach(group.themes) { theme in
                        themeRow(theme)
                    }
                } label: {
                    Label(
                        Constants.ThemeCategory.displayName(group.category),
                        systemImage: Constants.ThemeCategory.icons[group.category] ?? "circle.fill"
                    )
                    .font(.callout.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.quickEase) {
                            if expandedThemeCategory == group.category {
                                expandedThemeCategory = nil
                            } else {
                                expandedThemeCategory = group.category
                            }
                        }
                    }
                }
            }

            Text("선택한 테마는 메뉴바/타이머/버튼에 즉시 반영됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ThemeLivePreviewPanel()
        }
    }

    private func themeRow(_ theme: AppTheme) -> some View {
        let isSelected = theme.id == themeManager.selectedThemeID
        let isLocked = !licenseManager.isPro && !themeManager.isThemeFree(theme)

        return Button {
            if isLocked {
                paywallReason = .themeLimit
                showPaywall = true
            } else {
                withAnimation(.quickEase) {
                    themeManager.selectTheme(id: theme.id)
                }
            }
        } label: {
            HStack(spacing: Constants.Design.spacingMD) {
                // 확대된 색상 스와치
                themeSwatches(theme, isSelected: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Constants.Design.spacingXS) {
                        Text(theme.name)
                            .font(.callout.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isLocked ? .secondary : .primary)
                        if isLocked {
                            ProBadge()
                        }
                    }

                    // 미니 프리뷰 칩
                    miniTimerPreview(theme)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: theme.primaryHex))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, Constants.Design.spacingSM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func themeSwatches(_ theme: AppTheme, isSelected: Bool) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: theme.primaryHex))
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: theme.secondaryHex))
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: theme.accentHex))
        }
        .frame(width: 60, height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    isSelected ? Color(hex: theme.primaryHex).opacity(0.5) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: isSelected ? Color(hex: theme.primaryHex).opacity(0.15) : .clear,
            radius: 4
        )
    }

    private func miniTimerPreview(_ theme: AppTheme) -> some View {
        Text("25:00")
            .font(.caption2.weight(.medium).monospacedDigit())
            .foregroundStyle(Color(hex: theme.primaryHex))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Color(hex: theme.primaryHex).opacity(0.1),
                in: RoundedRectangle(cornerRadius: Constants.Design.cornerSM)
            )
    }

    // MARK: - 스케줄

    private var scheduleSection: some View {
        Section("스케줄") {
            proGatedToggle(
                "자동 스케줄",
                isOn: Bindable(viewModel).enableSchedule,
                feature: .schedule
            )

            Text("요일별로 자동 집중 세션을 시작합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.enableSchedule {
                ScheduleListView()
            }
        }
        .animation(.quickEase, value: viewModel.enableSchedule)
    }

    // MARK: - Focus Mode (v1.4)

    @State private var focusModeSetupComplete = false
    @State private var focusModeCheckingSetup = false
    @State private var focusModeInstalling = false
    @State private var focusModePollingTask: Task<Void, Never>?

    private var focusModeSection: some View {
        Section("macOS Focus Mode") {
            proGatedToggle(
                "Focus Mode 연동",
                isOn: Bindable(viewModel).enableFocusMode,
                feature: .focusModeIntegration
            )

            Text("집중 세션 시작 시 macOS 방해금지 모드를 자동으로 활성화합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.enableFocusMode {
                HStack(spacing: Constants.Design.spacingSM) {
                    if focusModeCheckingSetup {
                        ProgressView()
                            .controlSize(.small)
                        Text("단축어 확인 중...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if focusModeInstalling {
                        ProgressView()
                            .controlSize(.small)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shortcuts 앱에서 '추가'를 눌러주세요")
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Text("두 개의 단축어를 각각 추가해야 합니다.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else if focusModeSetupComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("단축어 설치 완료")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("재설치") {
                            startFocusModeSetup()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("단축어 설치 필요")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("설치") {
                            startFocusModeSetup()
                        }
                        .font(.caption)
                    }
                }
                .task {
                    focusModeCheckingSetup = true
                    focusModeSetupComplete = await FocusModeController.shared.checkSetup()
                    focusModeCheckingSetup = false
                }
                .onDisappear {
                    focusModePollingTask?.cancel()
                    focusModePollingTask = nil
                }
            }
        }
    }

    /// 단축어 설치 시작 → 파일 생성/서명/열기 → 자동 폴링으로 설치 감지
    private func startFocusModeSetup() {
        focusModeInstalling = true
        focusModePollingTask?.cancel()
        focusModePollingTask = Task {
            await FocusModeController.shared.performSetup()

            // 설치 완료까지 2초 간격으로 폴링 (최대 60초)
            for _ in 0..<30 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                let ready = await FocusModeController.shared.checkSetup()
                if ready {
                    focusModeSetupComplete = true
                    focusModeInstalling = false
                    return
                }
            }

            // 타임아웃: 설치 상태로 복귀
            focusModeInstalling = false
        }
    }

    // MARK: - 번아웃 방지 (v1.5)

    private var burnoutSection: some View {
        Section("번아웃 방지") {
            proGatedToggle(
                "번아웃 경고",
                isOn: Bindable(viewModel).enableBurnoutWarnings,
                feature: .burnoutWarnings
            )

            Text("일일 집중 한계에 가까워지면 긍정적 톤의 알림을 표시합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.enableBurnoutWarnings {
                HStack {
                    Text("일일 한계")
                    Spacer()
                    Text("\(Int(viewModel.burnoutDailyLimitHours))시간")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 40)
                }

                Slider(
                    value: Bindable(viewModel).burnoutDailyLimitHours,
                    in: Constants.Burnout.dailyLimitHoursRange,
                    step: 1
                )

                Text("90분 연속 집중 시 스트레칭 알림도 발송됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.quickEase, value: viewModel.enableBurnoutWarnings)
    }

    // MARK: - Apple Calendar

    private var calendarSection: some View {
        Section("Apple Calendar") {
            proGatedToggle(
                "완료 세션 캘린더에 기록",
                isOn: Bindable(viewModel).enableCalendarSync,
                feature: .calendarSync
            )

            Text("완료된 집중 세션이 Focus You 캘린더에 자동 기록됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 차단 전략 (v2.0)

    private var blockingStrategySection: some View {
        Section("차단 방식") {
            Picker(
                String(localized: "settings_blocking_strategy"),
                selection: Binding(
                    get: { viewModel.blockingStrategy },
                    set: { newValue in
                        if newValue == "networkExtension" && licenseManager.requiresPro(feature: .networkExtension) {
                            paywallReason = .proFeature(.networkExtension)
                            showPaywall = true
                        } else {
                            viewModel.blockingStrategy = newValue
                        }
                    }
                )
            ) {
                Text(String(localized: "settings_blocking_hosts"))
                    .tag("hosts")
                HStack {
                    Text(String(localized: "settings_blocking_ne"))
                    if !licenseManager.isPro {
                        ProBadge()
                    }
                }
                .tag("networkExtension")
            }

            if viewModel.blockingStrategy == "networkExtension" {
                Text(String(localized: "settings_blocking_ne_description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(String(localized: "settings_blocking_ne_active_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(String(localized: "settings_blocking_hosts_description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 진단

    private var diagnosticsSection: some View {
        Section("진단") {
            HealthCheckView()
        }
    }

    // MARK: - 디버그

    #if DEBUG
    private var debugSection: some View {
        Section("개발자") {
            Toggle(
                "Fast Timer (디버그)",
                isOn: Bindable(viewModel).debugFastTimerEnabled
            )

            HStack {
                Text("1분 = \(Int(viewModel.debugSecondsPerMinute))초")
                Spacer()
                Stepper(
                    "",
                    value: Bindable(viewModel).debugSecondsPerMinute,
                    in: Constants.Settings.debugSecondsPerMinuteRange,
                    step: 1
                )
                .labelsHidden()
                .disabled(!viewModel.debugFastTimerEnabled)
            }

            Text("세션 QA를 빠르게 검증할 때만 사용됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("온보딩 재설정") {
                viewModel.hasCompletedOnboarding = false
            }
        }
    }
    #endif

    // MARK: - 앱 재실행

    private func relaunchApp() {
        let appURL = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5 && open \"\(appURL.path)\""]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Pro 게이팅 헬퍼

    private func proGatedToggle(
        _ title: String,
        isOn: Binding<Bool>,
        feature: LicenseManager.ProFeature
    ) -> some View {
        HStack {
            Toggle(LocalizedStringKey(title), isOn: Binding(
                get: { isOn.wrappedValue },
                set: { newValue in
                    if newValue && licenseManager.requiresPro(feature: feature) {
                        paywallReason = .proFeature(feature)
                        showPaywall = true
                    } else {
                        isOn.wrappedValue = newValue
                    }
                }
            ))
            if !licenseManager.isPro {
                ProBadge()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .environment(LicenseManager.shared)
        .frame(width: 400)
}
