import XCTest
@testable import Focus_You

final class StringExtensionsTests: XCTestCase {
    func testNormalizedDomainStripsSchemePathQueryAndWWW() {
        let input = "https://www.Facebook.com/path?q=1#top"
        XCTAssertEqual(input.normalizedDomain, "facebook.com")
    }

    func testNormalizedDomainKeepsDomainWithoutScheme() {
        let input = "github.com"
        XCTAssertEqual(input.normalizedDomain, "github.com")
    }

    func testNormalizedDomainRejectsInvalidInput() {
        XCTAssertEqual("localhost".normalizedDomain, "")
        XCTAssertEqual("".normalizedDomain, "")
        XCTAssertEqual("https://".normalizedDomain, "")
    }
}
