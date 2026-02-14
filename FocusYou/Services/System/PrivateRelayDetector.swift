import Foundation
import os

// MARK: - iCloud Private Relay 감지

/// macOS의 iCloud Private Relay 활성화 상태를 감지합니다.
/// hosts 파일 기반 차단은 Private Relay가 켜져 있으면 Safari에서 우회됩니다.
enum PrivateRelayDetector {
    enum Status: Sendable {
        case enabled
        case disabled
        case unknown
    }

    private static let logger = Logger(
        subsystem: "com.yourname.focusyou",
        category: "PrivateRelayDetector"
    )

    /// Private Relay 활성화 상태를 감지합니다.
    /// `~/Library/Preferences/com.apple.networkserviceproxy.plist` 내
    /// `NSPServiceStatusManagerInfo` → `$objects[1].PrivacyProxyServiceStatus` 값을 확인합니다.
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

        guard let objects = innerPlist["$objects"] as? [Any],
              objects.count > 1,
              let serviceStatusDict = objects[1] as? [String: Any],
              let statusValue = serviceStatusDict["PrivacyProxyServiceStatus"] as? Int else {
            logger.debug("PrivacyProxyServiceStatus 값 추출 실패")
            return .unknown
        }

        let status: Status = statusValue == 1 ? .enabled : .disabled
        logger.info("Private Relay 상태: \(String(describing: status), privacy: .public)")
        return status
    }
}
