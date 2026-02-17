import Foundation
import NetworkExtension

// System Extension 진입점
// NEFilterDataProvider가 시스템에 의해 자동 로드됩니다.
autoreleasepool {
    NEProvider.startSystemExtensionMode()
}

dispatchMain()
