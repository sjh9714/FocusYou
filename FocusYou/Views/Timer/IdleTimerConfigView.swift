import SwiftUI

// MARK: - 유휴 상태 타이머 설정

struct IdleTimerConfigView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LicenseManager.self) private var licenseManager

    @Bindable var viewModel: TimerViewModel
    @Binding var showPaywall: Bool

    var body: some View {
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

        cancelIntensityPicker
    }

    // MARK: - 프리셋 칩

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
}

#Preview {
    IdleTimerConfigView(
        viewModel: TimerViewModel(),
        showPaywall: .constant(false)
    )
    .environment(ThemeManager.shared)
    .environment(LicenseManager.shared)
    .padding()
}
