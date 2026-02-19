import SwiftUI

// MARK: - 설정: 일반 탭

struct SettingsGeneralTabView: View {
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LicenseManager.self) private var licenseManager

    @State private var showPaywall = false
    @State private var paywallReason: PaywallReason = .proFeature(.unlimitedBlocks)
    @State private var expandedThemeCategory: String?
    @State private var isRestoring = false
    @State private var restoreMessage: String?
    @State private var showRestartAlert = false

    var body: some View {
        Form {
            subscriptionSection
            generalSection
            SettingsThemeSectionView(
                expandedThemeCategory: $expandedThemeCategory,
                showPaywall: $showPaywall,
                paywallReason: $paywallReason
            )
            infoSection
        }
        .formStyle(.grouped)
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

    // MARK: - 앱 재실행

    private func relaunchApp() {
        let appURL = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5 && open \"\(appURL.path)\""]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }
}

#Preview {
    SettingsGeneralTabView()
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .environment(LicenseManager.shared)
        .frame(width: 400)
}
