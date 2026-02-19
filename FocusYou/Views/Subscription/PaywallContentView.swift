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

    private func featureRow(icon: String, text: String) -> some View {
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
        VStack(spacing: Constants.Design.spacingXS) {
            HStack(spacing: Constants.Design.spacingSM) {
                if let annual = product(for: Constants.Subscription.annualProductID) {
                    pricingBadge(
                        product: annual,
                        period: String(localized: "subscription_period_year"),
                        highlight: selectedProduct?.id == annual.id
                    )
                    .onTapGesture { selectedProduct = annual }
                } else {
                    pricingBadgeFallback(
                        price: Constants.Subscription.annualDiscountPrice,
                        period: String(localized: "subscription_period_year"),
                        highlight: true
                    )
                }

                if let monthly = product(for: Constants.Subscription.monthlyProductID) {
                    pricingBadge(
                        product: monthly,
                        period: String(localized: "subscription_period_month"),
                        highlight: selectedProduct?.id == monthly.id
                    )
                    .onTapGesture { selectedProduct = monthly }
                } else {
                    pricingBadgeFallback(
                        price: Constants.Subscription.monthlyPrice,
                        period: String(localized: "subscription_period_month"),
                        highlight: false
                    )
                }
            }

            if let lifetime = product(for: Constants.Subscription.lifetimeProductID) {
                pricingBadge(
                    product: lifetime,
                    period: String(localized: "subscription_period_lifetime"),
                    highlight: selectedProduct?.id == lifetime.id
                )
                .onTapGesture { selectedProduct = lifetime }
            }

            Text("출시 기념 50% 할인 (정가 \(Constants.Subscription.annualPrice)/년)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 가격 배지

    private func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    private func pricingBadge(product: Product, period: String, highlight: Bool) -> some View {
        VStack(spacing: 2) {
            Text(product.displayPrice)
                .font(.title3.bold())
            Text(period)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.Design.spacingMD)
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

    private func pricingBadgeFallback(price: String, period: String, highlight: Bool) -> some View {
        VStack(spacing: 2) {
            Text(price)
                .font(.title3.bold())
            Text(period)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.Design.spacingMD)
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

#Preview {
    PaywallContentView(
        reason: .websiteLimit,
        products: [],
        selectedProduct: .constant(nil)
    )
    .environment(ThemeManager.shared)
    .padding()
}
