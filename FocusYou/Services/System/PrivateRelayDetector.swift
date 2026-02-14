import Foundation
import os

// MARK: - iCloud Private Relay 감지

/// macOS의 iCloud Private Relay 활성화 상태를 감지합니다.
/// hosts 파일 기반 차단은 Private Relay가 켜져 있으면 Safari에서 우회됩니다.
enum PrivateRelayDetector {
    enum Status: Sendable, Equatable {
        case enabled
        case disabled
        case unknown
    }

    private static let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "PrivateRelayDetector"
    )

    /// Private Relay 활성화 상태를 감지합니다.
    /// `~/Library/Preferences/com.apple.networkserviceproxy.plist` 내
    /// `NSPServiceStatusManagerInfo` 아카이브를 파싱하고
    /// `PrivacyProxyServiceStatus` 값을 재귀 탐색합니다.
    static func detect() -> Status {
        let plistPath = NSHomeDirectory()
            + "/Library/Preferences/com.apple.networkserviceproxy.plist"

        guard let plistData = FileManager.default.contents(atPath: plistPath) else {
            logger.debug("networkserviceproxy plist 파일 없음")
            return .unknown
        }

        guard let outerPlist = try? PropertyListSerialization.propertyList(
            from: plistData,
            options: [],
            format: nil
        ) as? [String: Any] else {
            logger.debug("외부 plist 파싱 실패")
            return .unknown
        }

        return detect(fromOuterPlist: outerPlist)
    }

    static func detect(fromOuterPlist outerPlist: [String: Any]) -> Status {
        guard let innerData = outerPlist["NSPServiceStatusManagerInfo"] as? Data else {
            logger.debug("NSPServiceStatusManagerInfo 키 없음")
            return .unknown
        }

        guard let innerPlist = try? PropertyListSerialization.propertyList(
            from: innerData,
            options: [],
            format: nil
        ) as? [String: Any] else {
            logger.debug("내부 plist (NSKeyedArchiver) 파싱 실패")
            return .unknown
        }

        guard let statusValue = extractStatusValue(from: innerPlist) else {
            logger.debug("PrivacyProxyServiceStatus 값 추출 실패")
            return .unknown
        }

        let status: Status = statusValue > 0 ? .enabled : .disabled
        logger.info("Private Relay 상태: \(String(describing: status), privacy: .public)")
        return status
    }

    private static func extractStatusValue(from object: Any) -> Int? {
        if let dict = object as? [String: Any] {
            if let intValue = dict["PrivacyProxyServiceStatus"] as? Int {
                return intValue
            }
            if let number = dict["PrivacyProxyServiceStatus"] as? NSNumber {
                return number.intValue
            }
            for value in dict.values {
                if let extracted = extractStatusValue(from: value) {
                    return extracted
                }
            }
            return nil
        }
        if let array = object as? [Any] {
            for value in array {
                if let extracted = extractStatusValue(from: value) {
                    return extracted
                }
            }
        }
        return nil
    }
}
