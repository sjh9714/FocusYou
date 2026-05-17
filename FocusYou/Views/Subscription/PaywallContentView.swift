import SwiftUI
import StoreKit

// MARK: - 페이월 콘텐츠 (헤더 + 기능 + 가격)

struct PaywallContentView: View {
    @Environment(ThemeManager.self) private var themeManager

    let reason: PaywallReason
    let products: [Product]
    @Binding var selectedProduct: Product?

    var body: some View {
        headerSection
        featureSection
        pricingSection
    }

    // MARK: - 헤더

    private var headerSection: some View {
        VStack(spacing: Constants.Design.spacingSM) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(themeManager.primary.gradient)

            Text("Pro로 업그레이드")
                .font(.title2.bold())

            Text(reason.message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 기능

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            featureRow(icon: "infinity", text: "무제한 차단 / 타이머 / 프로필")
            featureRow(icon: "brain.head.profile", text: "의도 입력 · 회고 · 동기부여 명언")
            featureRow(icon: "paintpalette.fill", text: "70+ 프리미엄 테마")
            featureRow(icon: "chart.bar.fill", text: "고급 통계 + 히트맵")
            featureRow(icon: "calendar", text: "스케줄 · 캘린더 · Shortcuts")
            featureRow(icon: "square.and.arrow.up", text: "데이터 내보내기 (CSV/JSON)")
        }
        .padding(Constants.Design.cardPadding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Constants.Design.cornerLG))
    }

    private func featureRow(icon: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: Constants.Design.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: Constants.Design.iconSM))
                .foregroundStyle(themeManager.primary)
                .frame(width: 20, alignment: .center)

            Text(text)
                .font(.callout)
        }
    }

    // MARK: - 가격

    private var pricingSection: some View {
        let visibleProductIDs = PaywallPlanPresentation.visibleProductIDs(
            from: products.map(\.id)
        )

        return VStack(spacing: Constants.Design.spacingXS) {
            if visibleProductIDs.isEmpty {
                Text(String(localized: "subscription_products_unavailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, Constants.Design.spacingSM)
            } else {
                HStack(spacing: Constants.Design.spacingSM) {
                    if let annual = product(for: Constants.Subscription.annualProductID) {
                        pricingButton(
                            product: annual,
                            period: String(localized: "subscription_period_year")
                        )
                    }

                    if let monthly = product(for: Constants.Subscription.monthlyProductID) {
                        pricingButton(
                            product: monthly,
                            period: String(localized: "subscription_period_month")
                        )
                    }
                }

                if let lifetime = product(for: Constants.Subscription.lifetimeProductID) {
                    pricingButton(
                        product: lifetime,
                        period: String(localized: "subscription_period_lifetime")
                    )
                }
            }

            if product(for: Constants.Subscription.annualProductID) != nil {
                Text(
                    String(
                        format: String(localized: "subscription_launch_discount_format"),
                        Constants.Subscription.annualPrice
                    )
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 가격 배지

    private func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    private func pricingButton(product: Product, period: String) -> some View {
        let disclosure = String(
            localized: String.LocalizationValue(
                PaywallPlanPresentation.renewalDisclosureKey(for: product.id)
            )
        )

        return Button {
            selectedProduct = product
        } label: {
            pricingBadge(
                product: product,
                period: period,
                disclosure: disclosure,
                highlight: selectedProduct?.id == product.id
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(product.displayName), \(product.displayPrice) \(period). \(disclosure)")
    }

    private func pricingBadge(
        product: Product,
        period: String,
        disclosure: String,
        highlight: Bool
    ) -> some View {
        VStack(spacing: 4) {
            Text(product.displayName)
                .font(.callout.bold())
                .multilineTextAlignment(.center)
            Text(product.displayPrice)
                .font(.title3.bold())
            Text(period)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(disclosure)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.Design.spacingMD)
        .padding(.horizontal, Constants.Design.spacingXS)
        .background(
            highlight
                ? AnyShapeStyle(themeManager.primary.opacity(0.1))
                : AnyShapeStyle(Color.secondary.opacity(0.06)),
            in: RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                .stroke(
                    highlight ? themeManager.primary.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

enum PaywallPlanPresentation {
    private static let displayOrder = [
        Constants.Subscription.annualProductID,
        Constants.Subscription.monthlyProductID,
        Constants.Subscription.lifetimeProductID,
    ]

    static func visibleProductIDs<S: Sequence>(from productIDs: S) -> [String]
    where S.Element == String {
        let returnedProductIDs = Set(productIDs)
        return displayOrder.filter { returnedProductIDs.contains($0) }
    }

    static func renewalDisclosureKey(for productID: String) -> String {
        switch productID {
        case Constants.Subscription.lifetimeProductID:
            return "subscription_lifetime_disclosure"
        case Constants.Subscription.annualProductID:
            return "subscription_annual_disclosure"
        default:
            return "subscription_monthly_disclosure"
        }
    }
}

#Preview {
    PaywallContentView(
        reason: .websiteLimit,
        products: [],
        selectedProduct: .constant(nil)
    )
    .environment(ThemeManager.shared)
    .padding()
}
