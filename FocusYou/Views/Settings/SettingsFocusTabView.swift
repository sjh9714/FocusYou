import SwiftUI

// MARK: - 설정: 집중 탭

struct SettingsFocusTabView: View {
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LicenseManager.self) private var licenseManager

    @State private var showPaywall = false
    @State private var paywallReason: PaywallReason = .proFeature(.unlimitedBlocks)

    var body: some View {
        Form {
            focusExperienceSection
            burnoutSection
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: paywallReason)
                .environment(themeManager)
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
    SettingsFocusTabView()
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .environment(LicenseManager.shared)
        .frame(width: 400)
}
