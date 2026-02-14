import Foundation
import XCTest
@testable import Focus_You

@MainActor
final class PrivateRelayDetectorTests: XCTestCase {
    func testDetectEnabledWhenStatusValueIsNested() throws {
        let innerPlist: [String: Any] = [
            "$objects": [
                "$null",
                ["unrelated": "value"],
                ["nested": ["PrivacyProxyServiceStatus": 1]]
            ]
        ]
        let outerPlist = ["NSPServiceStatusManagerInfo": try archivedData(from: innerPlist)]

        XCTAssertEqual(PrivateRelayDetector.detect(fromOuterPlist: outerPlist), .enabled)
    }

    func testDetectDisabledWhenStatusValueIsZero() throws {
        let innerPlist: [String: Any] = [
            "$objects": [
                "$null",
                ["PrivacyProxyServiceStatus": 0]
            ]
        ]
        let outerPlist = ["NSPServiceStatusManagerInfo": try archivedData(from: innerPlist)]

        XCTAssertEqual(PrivateRelayDetector.detect(fromOuterPlist: outerPlist), .disabled)
    }

    func testDetectReturnsUnknownWhenStatusValueMissing() throws {
        let innerPlist: [String: Any] = [
            "$objects": [
                "$null",
                ["notStatus": 10]
            ]
        ]
        let outerPlist = ["NSPServiceStatusManagerInfo": try archivedData(from: innerPlist)]

        XCTAssertEqual(PrivateRelayDetector.detect(fromOuterPlist: outerPlist), .unknown)
    }

    private func archivedData(from plist: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .binary,
            options: 0
        )
    }
}
