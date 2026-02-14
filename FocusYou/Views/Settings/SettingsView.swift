import SwiftUI

// MARK: - 설정 뷰 (v0.5 리디자인)

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(ThemeManager.self) private var themeManager

    @State private var isPreviewPlaying = false

    var body: some View {
        TabView {
            // 탭 1: 일반
            Form {
                generalSection
                themeSection
                infoSection
            }
            .formStyle(.grouped)
            .tabItem { Label("일반", systemImage: "gearshape") }

            // 탭 2: 집중
            Form {
                focusExperienceSection
                ambientSoundSection
                burnoutSection
            }
            .formStyle(.grouped)
            .tabItem { Label("집중", systemImage: "brain.head.profile") }

            // 탭 3: 연동
            Form {
                focusModeSection
                calendarSection
                scheduleSection
                appDimmingSection
            }
            .formStyle(.grouped)
            .tabItem { Label("연동", systemImage: "link") }

            // 탭 4: 고급
            Form {
                diagnosticsSection
                #if DEBUG
                debugSection
                #endif
            }
            .formStyle(.grouped)
            .tabItem { Label("고급", systemImage: "wrench.and.screwdriver") }
        }
    }

    // MARK: - 일반

    private var generalSection: some View {
        Section("일반") {
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
            Toggle("의도 입력", isOn: Bindable(viewModel).showIntentionInput)
            Text("세션 시작 전 집중할 내용을 입력합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("회고", isOn: Bindable(viewModel).showRetrospect)
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

    // MARK: - 주변음 섹션

    private var ambientSoundSection: some View {
        Section("주변음") {
            Toggle(
                "집중 시 배경 소리",
                isOn: Bindable(viewModel).enableAmbientSound
            )

            Text("세션 중 배경 노이즈를 재생합니다. 뽀모도로 휴식에는 자동 정지됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.enableAmbientSound {
                Picker("소리 종류", selection: Bindable(viewModel).ambientSoundTrack) {
                    ForEach(AmbientSoundTrack.allCases, id: \.rawValue) { track in
                        Label(track.displayName, systemImage: track.icon)
                            .tag(track.rawValue)
                    }
                }

                HStack {
                    Image(systemName: "speaker.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Bindable(viewModel).ambientSoundVolume,
                        in: Constants.Sound.volumeRange
                    )
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    toggleSoundPreview()
                } label: {
                    Label(
                        isPreviewPlaying ? "미리듣기 중지" : "미리듣기",
                        systemImage: isPreviewPlaying ? "stop.fill" : "play.fill"
                    )
                }
                .secondaryActionStyle(color: themeManager.primary)
            }
        }
        .animation(.quickEase, value: viewModel.enableAmbientSound)
    }

    private func toggleSoundPreview() {
        Task {
            if isPreviewPlaying {
                await AmbientSoundManager.shared.stop()
                isPreviewPlaying = false
            } else {
                let track = AmbientSoundTrack(rawValue: viewModel.ambientSoundTrack) ?? .whiteNoise
                await AmbientSoundManager.shared.play(
                    track: track,
                    volume: Float(viewModel.ambientSoundVolume)
                )
                isPreviewPlaying = true

                // 5초 후 자동 정지
                try? await Task.sleep(for: .seconds(5))
                await AmbientSoundManager.shared.stop()
                isPreviewPlaying = false
            }
        }
    }

    // MARK: - 테마 섹션

    private var themeSection: some View {
        Section("테마") {
            ForEach(themeManager.themesByCategory, id: \.category) { group in
                DisclosureGroup {
                    ForEach(group.themes) { theme in
                        themeRow(theme)
                    }
                } label: {
                    Label(
                        group.category,
                        systemImage: Constants.ThemeCategory.icons[group.category] ?? "circle.fill"
                    )
                    .font(.callout.weight(.medium))
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

        return Button {
            withAnimation(.quickEase) {
                themeManager.selectTheme(id: theme.id)
            }
        } label: {
            HStack(spacing: Constants.Design.spacingMD) {
                // 확대된 색상 스와치
                themeSwatches(theme, isSelected: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)

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
            Toggle(
                "자동 스케줄",
                isOn: Bindable(viewModel).enableSchedule
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

    private var focusModeSection: some View {
        Section("macOS Focus Mode") {
            Toggle(
                "Focus Mode 연동",
                isOn: Bindable(viewModel).enableFocusMode
            )

            Text("macOS 집중 모드 활성화 시 자동으로 집중 세션을 시작합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 앱 디밍 (v1.4)

    private var appDimmingSection: some View {
        Section("앱 디밍") {
            Toggle(
                "비활성 앱 디밍",
                isOn: Bindable(viewModel).enableAppDimming
            )

            Text("차단 앱 윈도우를 어둡게 표시하여 사용을 자제합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.enableAppDimming {
                HStack {
                    Text("불투명도")
                    Slider(
                        value: Bindable(viewModel).dimmingOpacity,
                        in: 0.1...0.8,
                        step: 0.1
                    )
                    Text("\(Int(viewModel.dimmingOpacity * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 36)
                }
            }
        }
        .animation(.quickEase, value: viewModel.enableAppDimming)
    }

    // MARK: - 번아웃 방지 (v1.5)

    private var burnoutSection: some View {
        Section("번아웃 방지") {
            Toggle(
                "번아웃 경고",
                isOn: Bindable(viewModel).enableBurnoutWarnings
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
            Toggle(
                "완료 세션 캘린더에 기록",
                isOn: Bindable(viewModel).enableCalendarSync
            )

            Text("완료된 집중 세션이 Focus You 캘린더에 자동 기록됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
}

#Preview {
    SettingsView()
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .frame(width: 400)
}
