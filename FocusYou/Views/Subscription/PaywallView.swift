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
            }
            .padding(Constants.Design.spacingXL)
        }
        .frame(minWidth: 360, maxWidth: 360, minHeight: 480, maxHeight: 600)
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
            } else {
                Button {
                    Task { await purchaseSelected() }
                } label: {
                    if let selected = selectedProduct {
                        Label(
                            String(localized: "subscription_purchase_button \(selected.displayPrice)"),
                            systemImage: "crown.fill"
                        )
                    } else {
                        Label("Pro로 업그레이드", systemImage: "crown.fill")
                    }
                }
                .primaryActionStyle(color: themeManager.primary)
                .disabled(selectedProduct == nil)
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

            Button("닫기") {
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 헬퍼

    private func loadProducts() async {
        await SubscriptionManager.shared.loadProducts()
        products = await SubscriptionManager.shared.products
        selectedProduct = products.first { $0.id == Constants.Subscription.annualProductID }
    }

    private func purchaseSelected() async {
        guard let selected = selectedProduct else { return }
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
            return "무료 버전은 최대 \(Constants.Subscription.freeWebsiteLimit)개의 사이트를 차단할 수 있습니다."
        case .appLimit:
            return "무료 버전은 최대 \(Constants.Subscription.freeAppLimit)개의 앱을 차단할 수 있습니다."
        case .profileLimit:
            return "무료 버전은 \(Constants.Subscription.freeProfileLimit)개의 프로필을 사용할 수 있습니다."
        case .timerLimit:
            return "무료 버전은 최대 \(Constants.Subscription.freeTimerMaxMinutes / 60)시간 타이머를 사용할 수 있습니다."
        case .themeLimit:
            return "\(Constants.Subscription.freeThemeLimit)개 이상의 테마는 Pro에서 사용할 수 있습니다."
        case .statsLimit:
            return "월간/연간 통계는 Pro에서 확인할 수 있습니다."
        case .retrospectLimit:
            return "상세 회고 기능은 Pro에서 사용할 수 있습니다."
        case .proFeature(let feature):
            return proFeatureMessage(feature)
        }
    }

    private func proFeatureMessage(_ feature: LicenseManager.ProFeature) -> String {
        switch feature {
        case .overflow: return "Overflow 모드는 Pro 기능입니다."
        case .schedule: return "자동 스케줄은 Pro 기능입니다."
        case .keywordBlocking: return "키워드 차단은 Pro 기능입니다."
        case .allowlistMode: return "화이트리스트 모드는 Pro 기능입니다."
        case .hardcoreMode: return "하드코어 모드는 Pro 기능입니다."
        case .focusModeIntegration: return "Focus Mode 연동은 Pro 기능입니다."
        case .shortcuts: return "Shortcuts 자동화는 Pro 기능입니다."
        case .calendarSync: return "캘린더 동기화는 Pro 기능입니다."
        case .dataExport: return "데이터 내보내기는 Pro 기능입니다."
        case .unlimitedBlocks: return "무제한 차단은 Pro 기능입니다."
        case .unlimitedTimer: return "무제한 타이머는 Pro 기능입니다."
        case .unlimitedProfiles: return "무제한 프로필은 Pro 기능입니다."
        case .premiumThemes: return "프리미엄 테마는 Pro 기능입니다."
        case .advancedStats: return "고급 통계는 Pro 기능입니다."
        case .advancedRetrospect: return "상세 회고는 Pro 기능입니다."
        case .intentionInput: return "의도 입력은 Pro 기능입니다."
        case .motivationQuotes: return "동기부여 명언은 Pro 기능입니다."
        case .retrospect: return "회고 기능은 Pro 기능입니다."
        case .burnoutWarnings: return "번아웃 방지는 Pro 기능입니다."
        case .networkExtension: return "Network Extension 차단은 Pro 기능입니다."
        }
    }
}

#Preview {
    PaywallView(reason: .websiteLimit)
        .environment(ThemeManager.shared)
}
