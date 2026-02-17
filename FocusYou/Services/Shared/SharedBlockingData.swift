import Foundation

// MARK: - Network Extension 차단 도메인 공유

/// 메인 앱 ↔ Network Extension 간 차단 도메인 공유 모델
struct SharedBlockingDomains: Codable, Sendable {
    let domains: [String]
    let isActive: Bool
    let updatedAt: Date
}

/// App Groups UserDefaults를 통한 차단 도메인 공유
enum SharedBlockingData {
    private static let key = "sharedBlockingDomains"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Constants.AppGroups.identifier)
    }

    /// 차단 도메인 쓰기 (메인 앱에서 호출)
    static func write(_ data: SharedBlockingDomains) {
        guard let defaults = sharedDefaults else { return }
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: key)
        defaults.synchronize()  // 크로스 프로세스 동기화 보장
    }

    /// 차단 도메인 읽기 (Network Extension에서 호출)
    static func read() -> SharedBlockingDomains? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedBlockingDomains.self, from: data)
    }

    /// 차단 해제 시 데이터 삭제
    static func clear() {
        guard let defaults = sharedDefaults else { return }
        defaults.removeObject(forKey: key)
        defaults.synchronize()  // 크로스 프로세스 동기화 보장
    }
}
