import Foundation

// MARK: - 앱 전체 에러 타입

enum FocusYouError: LocalizedError {
    case hostsFileAccessDenied
    case hostsFileReadFailed
    case hostsFileWriteFailed
    case dnsFlushFailed
    case appNotFound(bundleId: String)
    case appTerminationFailed(name: String)
    case timerAlreadyRunning
    case timerNotRunning
    case blockingAlreadyActive
    case authorizationFailed
    case authorizationCancelled
    case launchAgentInstallFailed
    case presetLoadFailed(category: String)

    var errorDescription: String? {
        switch self {
        case .hostsFileAccessDenied:
            return "hosts 파일 접근 권한이 없습니다. 관리자 권한이 필요합니다."
        case .hostsFileReadFailed:
            return "hosts 파일을 읽을 수 없습니다."
        case .hostsFileWriteFailed:
            return "hosts 파일에 쓸 수 없습니다."
        case .dnsFlushFailed:
            return "DNS 캐시를 플러시할 수 없습니다."
        case .appNotFound(let bundleId):
            return "앱을 찾을 수 없습니다: \(bundleId)"
        case .appTerminationFailed(let name):
            return "\(name) 앱을 종료할 수 없습니다."
        case .timerAlreadyRunning:
            return "타이머가 이미 실행 중입니다."
        case .timerNotRunning:
            return "실행 중인 타이머가 없습니다."
        case .blockingAlreadyActive:
            return "차단이 이미 활성화되어 있습니다."
        case .authorizationFailed:
            return "관리자 권한을 얻을 수 없습니다."
        case .authorizationCancelled:
            return "사용자가 관리자 권한 요청을 취소했습니다."
        case .launchAgentInstallFailed:
            return "안전장치(LaunchAgent)를 설치할 수 없습니다."
        case .presetLoadFailed(let category):
            return "\(category) 프리셋을 불러올 수 없습니다."
        }
    }
}
