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
            return String(localized: "error_hosts_access_denied")
        case .hostsFileReadFailed:
            return String(localized: "error_hosts_read_failed")
        case .hostsFileWriteFailed:
            return String(localized: "error_hosts_write_failed")
        case .dnsFlushFailed:
            return String(localized: "error_dns_flush_failed")
        case .appNotFound(let bundleId):
            return String(localized: "error_app_not_found \(bundleId)")
        case .appTerminationFailed(let name):
            return String(localized: "error_app_termination_failed \(name)")
        case .timerAlreadyRunning:
            return String(localized: "error_timer_already_running")
        case .timerNotRunning:
            return String(localized: "error_timer_not_running")
        case .blockingAlreadyActive:
            return String(localized: "error_blocking_already_active")
        case .authorizationFailed:
            return String(localized: "error_authorization_failed")
        case .authorizationCancelled:
            return String(localized: "error_authorization_cancelled")
        case .launchAgentInstallFailed:
            return String(localized: "error_launch_agent_failed")
        case .presetLoadFailed(let category):
            return String(localized: "error_preset_load_failed \(category)")
        }
    }
}
