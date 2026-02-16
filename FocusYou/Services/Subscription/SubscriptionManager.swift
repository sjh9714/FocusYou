import StoreKit
import os

// MARK: - 구독 관리자 (v2.0)
// StoreKit 2 API를 통한 인앱 구매/구독 관리

actor SubscriptionManager {
    static let shared = SubscriptionManager()

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "Subscription"
    )

    // MARK: - 상태

    /// 로드된 StoreKit 상품 목록
    private(set) var products: [Product] = []

    /// 현재 구매/구독이 유효한 상품 ID
    private(set) var purchasedProductIDs: Set<String> = []

    /// 상품 로딩 중 여부
    private(set) var isLoading = false

    /// 트랜잭션 감시 Task
    private var updateListenerTask: Task<Void, Never>?

    private init() {}

    // MARK: - 상품 로드

    /// App Store에서 상품 정보를 로드
    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(
                for: Constants.Subscription.allProductIDs
            )
            // 월간 → 연간 → 평생 순서로 정렬
            products = storeProducts.sorted { lhs, rhs in
                productSortOrder(lhs) < productSortOrder(rhs)
            }
            logger.info("상품 \(storeProducts.count)개 로드 완료")
        } catch {
            logger.error("상품 로드 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - 구매

    /// 상품 구매 실행
    @discardableResult
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
            logger.info("구매 완료: \(product.id)")
            return transaction

        case .userCancelled:
            logger.info("사용자가 구매를 취소함: \(product.id)")
            return nil

        case .pending:
            logger.info("구매 승인 대기 중: \(product.id)")
            return nil

        @unknown default:
            logger.warning("알 수 없는 구매 결과: \(product.id)")
            return nil
        }
    }

    // MARK: - 구매 복원

    /// App Store에서 구매 내역을 동기화
    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
        logger.info("구매 복원 완료")
    }

    // MARK: - 권한 확인

    /// 현재 유효한 구매/구독을 확인하고 LicenseManager 갱신
    func refreshEntitlements() async {
        var validIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else {
                continue
            }

            if transaction.revocationDate == nil {
                validIDs.insert(transaction.productID)
            }
        }

        purchasedProductIDs = validIDs
        let hasPro = !validIDs.isEmpty
        logger.info("권한 확인 완료: Pro=\(hasPro), 상품=\(validIDs)")

        await MainActor.run {
            LicenseManager.shared.updateProStatus(hasPro)
        }
    }

    // MARK: - 트랜잭션 실시간 감시

    /// 앱 생명주기 동안 트랜잭션 업데이트를 감시
    func listenForTransactionUpdates() {
        // 기존 리스너가 있으면 취소
        updateListenerTask?.cancel()

        updateListenerTask = Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try await self.checkVerified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    self.logger.error("트랜잭션 업데이트 검증 실패: \(error.localizedDescription)")
                }
            }
        }

        logger.info("트랜잭션 감시 시작")
    }

    // MARK: - 구독 정보

    /// 현재 활성 구독의 갱신/만료 날짜
    func activeSubscriptionExpirationDate() async -> Date? {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else {
                continue
            }
            if transaction.revocationDate == nil {
                return transaction.expirationDate
            }
        }
        return nil
    }

    /// 현재 활성 구독의 상품 ID (구독 유형 표시용)
    func activeProductID() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else {
                continue
            }
            if transaction.revocationDate == nil {
                return transaction.productID
            }
        }
        return nil
    }

    // MARK: - 헬퍼

    /// 상품을 월간 → 연간 → 평생 순으로 정렬하기 위한 키
    private func productSortOrder(_ product: Product) -> Int {
        switch product.id {
        case Constants.Subscription.monthlyProductID: return 0
        case Constants.Subscription.annualProductID: return 1
        case Constants.Subscription.lifetimeProductID: return 2
        default: return 3
        }
    }

    /// StoreKit 검증 결과에서 유효한 트랜잭션 추출
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            logger.error("트랜잭션 검증 실패: \(error.localizedDescription)")
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - 구독 에러

enum SubscriptionError: LocalizedError {
    case verificationFailed
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return String(localized: "error_subscription_verification_failed")
        case .productNotFound:
            return String(localized: "error_subscription_product_not_found")
        }
    }
}
