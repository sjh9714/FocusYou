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
            themeSection
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

    // MARK: - 테마

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
