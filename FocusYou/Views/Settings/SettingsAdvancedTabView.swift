import SwiftUI

// MARK: - 설정: 고급 탭

struct SettingsAdvancedTabView: View {
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LicenseManager.self) private var licenseManager

    @State private var showPaywall = false
    @State private var paywallReason: PaywallReason = .proFeature(.unlimitedBlocks)

    var body: some View {
        Form {
            blockingStrategySection
            diagnosticsSection
            #if DEBUG
            debugSection
            #endif
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: paywallReason)
                .environment(themeManager)
        }
    }

    // MARK: - 차단 전략 (v2.0)

    private var blockingStrategySection: some View {
        Section("차단 방식") {
            if Constants.Distribution.isAppStoreBuild {
                appStoreBlockingStrategyContent
            } else {
                directDistributionBlockingStrategyContent
            }
        }
    }

    private var appStoreBlockingStrategyContent: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            Label(
                String(localized: "settings_blocking_ne"),
                systemImage: "network.badge.shield.half.filled"
            )
            .font(.callout.weight(.medium))

            Text(String(localized: "settings_blocking_appstore_ne_locked"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(String(localized: "settings_blocking_ne_active_hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var directDistributionBlockingStrategyContent: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
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
}

#Preview {
    SettingsAdvancedTabView()
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .environment(LicenseManager.shared)
        .frame(width: 400)
}
