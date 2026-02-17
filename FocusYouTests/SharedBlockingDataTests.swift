import XCTest
@testable import Focus_You

final class SharedBlockingDataTests: XCTestCase {
    func testSharedBlockingDomainsEncodeAndDecode() throws {
        let original = SharedBlockingDomains(
            domains: ["example.com", "github.com"],
            isActive: true,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SharedBlockingDomains.self, from: encoded)

        XCTAssertEqual(decoded.domains, ["example.com", "github.com"])
        XCTAssertTrue(decoded.isActive)
        XCTAssertEqual(decoded.updatedAt, original.updatedAt)
    }

    func testSharedBlockingDomainsEmptyDomains() throws {
        let original = SharedBlockingDomains(
            domains: [],
            isActive: false,
            updatedAt: Date()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SharedBlockingDomains.self, from: encoded)

        XCTAssertTrue(decoded.domains.isEmpty)
        XCTAssertFalse(decoded.isActive)
    }

    func testSharedBlockingDomainsRoundTripPreservesAllFields() throws {
        let now = Date()
        let original = SharedBlockingDomains(
            domains: ["a.com", "b.com", "c.com"],
            isActive: true,
            updatedAt: now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let restored = try decoder.decode(SharedBlockingDomains.self, from: data)

        XCTAssertEqual(restored.domains, original.domains)
        XCTAssertEqual(restored.isActive, original.isActive)
        // ISO 8601은 밀리초 이하를 잘라낼 수 있으므로 1초 오차 허용
        XCTAssertEqual(
            restored.updatedAt.timeIntervalSince1970,
            now.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func testSharedBlockingDomainsIsSendable() {
        // Sendable 컴파일 검증 (Strict Concurrency)
        let data = SharedBlockingDomains(
            domains: ["test.com"],
            isActive: true,
            updatedAt: Date()
        )

        let _: Sendable = data
    }
}
