import SwiftUI

// MARK: - 설정: 연동 탭

struct SettingsIntegrationTabView: View {
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LicenseManager.self) private var licenseManager

    @State private var showPaywall = false
    @State private var paywallReason: PaywallReason = .proFeature(.unlimitedBlocks)
    @State private var focusModeSetupComplete = false
    @State private var focusModeCheckingSetup = false
    @State private var focusModeInstalling = false
    @State private var focusModePollingTask: Task<Void, Never>?

    var body: some View {
        Form {
            focusModeSection
            calendarSection
            scheduleSection
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: paywallReason)
                .environment(themeManager)
        }
    }

    // MARK: - Focus Mode (v1.4)

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
    SettingsIntegrationTabView()
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .environment(LicenseManager.shared)
        .frame(width: 400)
}
