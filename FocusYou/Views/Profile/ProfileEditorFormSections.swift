import SwiftUI

// MARK: - 프로필 에디터 폼 섹션

struct ProfileEditorFormSections: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LicenseManager.self) private var licenseManager
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        iconSection
        colorSection
        timerSection
        cancelIntensitySection
    }

    // MARK: - 아이콘 피커

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            Text("아이콘")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 8),
                spacing: Constants.Design.spacingSM
            ) {
                ForEach(Constants.Design.profileIcons, id: \.self) { iconName in
                    let isSelected = viewModel.editorIcon == iconName

                    Button {
                        withAnimation(.quickEase) {
                            viewModel.editorIcon = iconName
                        }
                    } label: {
                        Image(systemName: iconName)
                            .font(.system(size: 16))
                            .foregroundStyle(
                                isSelected ? Color(hex: viewModel.editorColor) : .secondary
                            )
                            .frame(width: 36, height: 36)
                            .contentShape(RoundedRectangle(cornerRadius: Constants.Design.cornerSM))
                            .background(
                                isSelected
                                    ? Color(hex: viewModel.editorColor).opacity(0.12)
                                    : Color.secondary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: Constants.Design.cornerSM)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Constants.Design.cornerSM)
                                    .stroke(
                                        isSelected ? Color(hex: viewModel.editorColor).opacity(0.3) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 컬러 피커

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            Text("색상")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 6),
                spacing: Constants.Design.spacingSM
            ) {
                ForEach(Constants.Design.profileColors, id: \.self) { hex in
                    let isSelected = viewModel.editorColor == hex

                    Button {
                        withAnimation(.quickEase) {
                            viewModel.editorColor = hex
                        }
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(nsColor: .controlBackgroundColor), lineWidth: isSelected ? 3 : 0)
                            )
                            .shadow(
                                color: isSelected ? Color(hex: hex).opacity(0.4) : .clear,
                                radius: 4
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 타이머 설정

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            Text("타이머 설정")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: Constants.Design.spacingSM) {
                timerModeChip("자유", mode: "free")
                timerModeChip("뽀모도로", mode: "pomodoro")
                timerModeChip("플로우", mode: "flowmodoro")
            }

            if viewModel.editorTimerMode == "flowmodoro" {
                Text("집중이 끝나면 자동으로 휴식 시간이 계산됩니다.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(spacing: Constants.Design.spacingSM) {
                    timerRow(
                        icon: "bolt.fill",
                        title: "집중",
                        value: $viewModel.editorFocusMinutes,
                        range: 5...120,
                        color: Color(hex: viewModel.editorColor)
                    )

                    if viewModel.editorTimerMode == "pomodoro" {
                        timerRow(
                            icon: "cup.and.saucer.fill",
                            title: "짧은 휴식",
                            value: $viewModel.editorBreakMinutes,
                            range: 1...30,
                            color: themeManager.secondary
                        )
                        timerRow(
                            icon: "clock.fill",
                            title: "긴 휴식",
                            value: $viewModel.editorLongBreakMinutes,
                            range: 5...45,
                            color: themeManager.accent
                        )
                        timerRow(
                            icon: "arrow.2.squarepath",
                            title: "사이클",
                            value: $viewModel.editorCycles,
                            range: 2...8,
                            color: Color(hex: viewModel.editorColor)
                        )
                    }
                }
                .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
            }
        }
    }

    // MARK: - 취소 강도

    private var cancelIntensitySection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            Text("취소 강도")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: Constants.Design.spacingSM) {
                cancelIntensityChip("기본", level: 0, proRequired: false)
                cancelIntensityChip("강함", level: 1, proRequired: true)
                cancelIntensityChip("하드코어", level: 2, proRequired: true)
            }

            switch viewModel.editorCancelIntensity {
            case 0:
                Text("확인 다이얼로그로 중지합니다.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            case 1:
                HStack(spacing: Constants.Design.spacingSM) {
                    IconBadge(
                        systemName: "lock.fill",
                        color: Color(hex: viewModel.editorColor),
                        size: 24
                    )
                    Text("잠금 시간")
                        .font(.callout)
                    Spacer()
                    Stepper {
                        Text("\(viewModel.editorCancelLockoutMinutes)분")
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color(hex: viewModel.editorColor))
                    } onIncrement: {
                        viewModel.editorCancelLockoutMinutes = min(
                            Constants.CancelIntensity.lockoutMinutesRange.upperBound,
                            viewModel.editorCancelLockoutMinutes + 1
                        )
                    } onDecrement: {
                        viewModel.editorCancelLockoutMinutes = max(
                            Constants.CancelIntensity.lockoutMinutesRange.lowerBound,
                            viewModel.editorCancelLockoutMinutes - 1
                        )
                    }
                    .fixedSize()
                }
                .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)

                Text("세션 시작 후 설정한 시간 동안 중지할 수 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            default:
                Text("중지가 불가능합니다. 비상 해제만 가능합니다 (2분 대기, 1일 1회).")
                    .font(.caption)
                    .foregroundStyle(themeManager.stopButton.opacity(0.8))
            }
        }
    }

    // MARK: - 헬퍼

    private func timerModeChip(_ title: String, mode: String) -> some View {
        ChipButton(
            title: title,
            isSelected: viewModel.editorTimerMode == mode,
            color: Color(hex: viewModel.editorColor)
        ) {
            withAnimation(.quickEase) {
                viewModel.editorTimerMode = mode
            }
        }
    }

    private func cancelIntensityChip(_ title: String, level: Int, proRequired: Bool) -> some View {
        let isBlocked = proRequired && licenseManager.requiresPro(feature: .hardcoreMode)
        return HStack(spacing: 2) {
            ChipButton(
                title: title,
                isSelected: viewModel.editorCancelIntensity == level,
                color: Color(hex: viewModel.editorColor)
            ) {
                if isBlocked { return }
                withAnimation(.quickEase) {
                    viewModel.editorCancelIntensity = level
                }
            }
            if isBlocked {
                ProBadge()
            }
        }
    }

    private func timerRow(
        icon: String,
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        color: Color
    ) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            IconBadge(systemName: icon, color: color, size: 24)

            Text(title)
                .font(.callout)

            Spacer()

            Stepper {
                Text("\(value.wrappedValue)\(title == "사이클" ? "회" : "분")")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            } onIncrement: {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
            } onDecrement: {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
            }
            .fixedSize()
        }
    }
}

#Preview {
    ProfileEditorFormSections(viewModel: ProfileViewModel())
        .environment(ThemeManager.shared)
        .environment(LicenseManager.shared)
        .padding()
}
