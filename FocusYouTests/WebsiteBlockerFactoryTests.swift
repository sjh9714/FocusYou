import XCTest
@testable import Focus_You

final class WebsiteBlockerFactoryTests: XCTestCase {
    private let strategyKey = Constants.Settings.blockingStrategyKey

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: strategyKey)
        super.tearDown()
    }

    func testCreateHostsStrategyReturnsHostsFileBlocker() {
        let blocker = WebsiteBlockerFactory.create(strategy: .hosts)
        XCTAssertTrue(blocker is HostsFileBlocker)
    }

    func testCreateNetworkExtensionStrategyReturnsNetworkExtensionBlocker() {
        let blocker = WebsiteBlockerFactory.create(strategy: .networkExtension)
        XCTAssertTrue(blocker is NetworkExtensionBlocker)
    }

    func testCurrentStrategyDefaultsToHosts() {
        UserDefaults.standard.removeObject(forKey: strategyKey)
        XCTAssertEqual(WebsiteBlockerFactory.currentStrategy(), .hosts)
    }

    func testCurrentStrategyReadsHostsFromUserDefaults() {
        UserDefaults.standard.set("hosts", forKey: strategyKey)
        XCTAssertEqual(WebsiteBlockerFactory.currentStrategy(), .hosts)
    }

    func testCurrentStrategyReadsNetworkExtensionFromUserDefaults() {
        UserDefaults.standard.set("networkExtension", forKey: strategyKey)
        XCTAssertEqual(WebsiteBlockerFactory.currentStrategy(), .networkExtension)
    }

    func testCurrentStrategyFallsBackToHostsForInvalidValue() {
        UserDefaults.standard.set("invalidStrategy", forKey: strategyKey)
        XCTAssertEqual(WebsiteBlockerFactory.currentStrategy(), .hosts)
    }

    func testCreateWithDefaultParameterUsesCurrentStrategy() {
        UserDefaults.standard.set("networkExtension", forKey: strategyKey)
        let blocker = WebsiteBlockerFactory.create()
        XCTAssertTrue(blocker is NetworkExtensionBlocker)
    }

    func testBlockingStrategyCaseIterableContainsBothCases() {
        XCTAssertEqual(BlockingStrategy.allCases, [.hosts, .networkExtension])
    }

    func testBlockingStrategyRawValues() {
        XCTAssertEqual(BlockingStrategy.hosts.rawValue, "hosts")
        XCTAssertEqual(BlockingStrategy.networkExtension.rawValue, "networkExtension")
    }
}
