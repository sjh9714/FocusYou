import SwiftUI
import StoreKit

// MARK: - 페이월 뷰 (v2.0)
// 무료 한도 초과 시 자연스럽게 Pro 업그레이드를 안내하는 시트

struct PaywallView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    /// 페이월 트리거 이유
    let reason: PaywallReason

    @State private var products: [Product] = []
    @State private var isPurchasing = false
    @State private var isLoadingProducts = false
    @State private var didAttemptProductLoad = false
    @State private var selectedProduct: Product?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Constants.Design.spacingXL) {
                PaywallContentView(
                    reason: reason,
                    products: products,
                    selectedProduct: $selectedProduct
                )
                actionSection
                legalSection
            }
            .padding(Constants.Design.spacingXL)
        }
        .frame(
            minWidth: 380,
            idealWidth: 420,
            maxWidth: 520,
            minHeight: 520,
            idealHeight: 620,
            maxHeight: 720
        )
        .task {
            await loadProducts()
        }
    }

    // MARK: - 액션

    private var actionSection: some View {
        VStack(spacing: Constants.Design.spacingSM) {
            if isPurchasing {
                ProgressView()
                    .controlSize(.regular)
                    .padding(.vertical, Constants.Design.spacingSM)
            } else if isLoadingProducts {
                ProgressView(String(localized: "subscription_loading_products"))
                    .controlSize(.regular)
                    .padding(.vertical, Constants.Design.spacingSM)
            } else if products.isEmpty {
                Button {
                    Task { await loadProducts() }
                } label: {
                    Label(
                        String(localized: "subscription_retry_loading"),
                        systemImage: "arrow.clockwise"
                    )
                }
                .secondaryActionStyle(color: themeManager.primary)
            } else {
                Button {
                    Task { await purchaseSelected() }
                } label: {
                    if let selected = selectedProduct {
                        Label(
                            purchaseButtonTitle(for: selected),
                            systemImage: "crown.fill"
                        )
                    } else {
                        Label(String(localized: "Pro로 업그레이드"), systemImage: "crown.fill")
                    }
                }
                .primaryActionStyle(color: themeManager.primary)
                .disabled(selectedProduct == nil || products.isEmpty)
            }

            Button {
                Task { await restorePurchases() }
            } label: {
                Text(String(localized: "subscription_restore"))
            }
            .secondaryActionStyle(color: themeManager.primary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(String(localized: "닫기")) {
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private var legalSection: some View {
        VStack(spacing: Constants.Design.spacingXS) {
            Text(String(localized: "subscription_legal_notice"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: Constants.Design.spacingSM) {
                if let privacyURL = URL(string: Constants.Subscription.privacyPolicyURL) {
                    Link(
                        String(localized: "subscription_privacy_policy"),
                        destination: privacyURL
                    )
                }

                Text("·")
                    .foregroundStyle(.tertiary)

                if let termsURL = URL(string: Constants.Subscription.termsOfUseURL) {
                    Link(
                        String(localized: "subscription_terms_of_use"),
                        destination: termsURL
                    )
                }
            }
            .font(.caption)
        }
    }

    // MARK: - 헬퍼

    private func loadProducts() async {
        isLoadingProducts = true
        didAttemptProductLoad = true
        errorMessage = nil

        await SubscriptionManager.shared.loadProducts()
        products = await SubscriptionManager.shared.products
        selectedProduct = if products.isEmpty {
            nil
        } else {
            products.first { $0.id == Constants.Subscription.annualProductID }
                ?? products.first
        }

        if products.isEmpty {
            errorMessage = String(localized: "subscription_products_unavailable")
        }

        isLoadingProducts = false
    }

    private func purchaseSelected() async {
        guard let selected = selectedProduct else {
            errorMessage = didAttemptProductLoad
                ? String(localized: "subscription_products_unavailable")
                : String(localized: "subscription_loading_products")
            return
        }
        isPurchasing = true
        errorMessage = nil

        do {
            let transaction = try await SubscriptionManager.shared.purchase(selected)
            if transaction != nil {
                dismiss()
            }
        } catch {
            errorMessage = String(localized: "subscription_purchase_error \(error.localizedDescription)")
        }

        isPurchasing = false
    }

    private func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil

        do {
            try await SubscriptionManager.shared.restorePurchases()
            let purchased = await SubscriptionManager.shared.purchasedProductIDs
            if purchased.isEmpty {
                errorMessage = String(localized: "subscription_restore_no_purchases")
            } else {
                dismiss()
            }
        } catch {
            errorMessage = String(localized: "subscription_purchase_error \(error.localizedDescription)")
        }

        isPurchasing = false
    }

    private func purchaseButtonTitle(for product: Product) -> String {
        if product.id == Constants.Subscription.lifetimeProductID {
            return String(localized: "subscription_buy_button \(product.displayPrice)")
        }

        return String(localized: "subscription_purchase_button \(product.displayPrice)")
    }
}

// MARK: - 페이월 트리거 이유

enum PaywallReason {
    case websiteLimit
    case appLimit
    case profileLimit
    case timerLimit
    case themeLimit
    case statsLimit
    case retrospectLimit
    case proFeature(LicenseManager.ProFeature)

    var message: String {
        switch self {
        case .websiteLimit:
            return Self.localizedFormat(
                "paywall_reason_website_limit_format",
                Constants.Subscription.freeWebsiteLimit
            )
        case .appLimit:
            return Self.localizedFormat(
                "paywall_reason_app_limit_format",
                Constants.Subscription.freeAppLimit
            )
        case .profileLimit:
            return Self.localizedFormat(
                "paywall_reason_profile_limit_format",
                Constants.Subscription.freeProfileLimit
            )
        case .timerLimit:
            return Self.localizedFormat(
                "paywall_reason_timer_limit_format",
                Constants.Subscription.freeTimerMaxMinutes / 60
            )
        case .themeLimit:
            return Self.localizedFormat(
                "paywall_reason_theme_limit_format",
                Constants.Subscription.freeThemeLimit
            )
        case .statsLimit:
            return String(localized: "paywall_reason_stats_limit")
        case .retrospectLimit:
            return String(localized: "paywall_reason_retrospect_limit")
        case .proFeature(let feature):
            return proFeatureMessage(feature)
        }
    }

    private static func localizedFormat(_ key: String, _ value: Int) -> String {
        String(format: String(localized: String.LocalizationValue(key)), value)
    }

    private func proFeatureMessage(_ feature: LicenseManager.ProFeature) -> String {
        switch feature {
        case .overflow: return String(localized: "paywall_feature_overflow")
        case .schedule: return String(localized: "paywall_feature_schedule")
        case .keywordBlocking: return String(localized: "paywall_feature_keyword_blocking")
        case .allowlistMode: return String(localized: "paywall_feature_allowlist_mode")
        case .hardcoreMode: return String(localized: "paywall_feature_hardcore_mode")
        case .focusModeIntegration: return String(localized: "paywall_feature_focus_mode")
        case .shortcuts: return String(localized: "paywall_feature_shortcuts")
        case .calendarSync: return String(localized: "paywall_feature_calendar_sync")
        case .dataExport: return String(localized: "paywall_feature_data_export")
        case .unlimitedBlocks: return String(localized: "paywall_feature_unlimited_blocks")
        case .unlimitedTimer: return String(localized: "paywall_feature_unlimited_timer")
        case .unlimitedProfiles: return String(localized: "paywall_feature_unlimited_profiles")
        case .premiumThemes: return String(localized: "paywall_feature_premium_themes")
        case .advancedStats: return String(localized: "paywall_feature_advanced_stats")
        case .advancedRetrospect: return String(localized: "paywall_feature_advanced_retrospect")
        case .intentionInput: return String(localized: "paywall_feature_intention_input")
        case .motivationQuotes: return String(localized: "paywall_feature_motivation_quotes")
        case .retrospect: return String(localized: "paywall_feature_retrospect")
        case .burnoutWarnings: return String(localized: "paywall_feature_burnout_warnings")
        case .networkExtension: return String(localized: "paywall_feature_network_extension")
        }
    }
}

#Preview {
    PaywallView(reason: .websiteLimit)
        .environment(ThemeManager.shared)
}
