import Foundation
import os

// MARK: - 비주얼 성장 시스템 (v1.5)
// 누적 집중 시간 기반 5단계 성장

enum GrowthStage: Int, CaseIterable, Comparable {
    case seed = 0       // 0-10h
    case sprout = 1     // 10-50h
    case tree = 2       // 50-150h
    case forest = 3     // 150-500h
    case garden = 4     // 500h+

    var emoji: String {
        switch self {
        case .seed: return "🌱"
        case .sprout: return "🌿"
        case .tree: return "🌳"
        case .forest: return "🌲"
        case .garden: return "🏞️"
        }
    }

    var name: String {
        switch self {
        case .seed: return String(localized: "growth_seed")
        case .sprout: return String(localized: "growth_sprout")
        case .tree: return String(localized: "growth_tree")
        case .forest: return String(localized: "growth_forest")
        case .garden: return String(localized: "growth_garden")
        }
    }

    /// 이 단계의 시작 시간 (hours)
    var thresholdHours: Double {
        switch self {
        case .seed: return 0
        case .sprout: return 10
        case .tree: return 50
        case .forest: return 150
        case .garden: return 500
        }
    }

    /// 다음 단계의 시작 시간 (hours), 마지막 단계는 nil
    var nextThresholdHours: Double? {
        switch self {
        case .seed: return 10
        case .sprout: return 50
        case .tree: return 150
        case .forest: return 500
        case .garden: return nil
        }
    }

    static func < (lhs: GrowthStage, rhs: GrowthStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

@MainActor
enum GrowthManager {
    private static let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "GrowthManager"
    )

    /// 누적 집중 시간(hours) 기반 현재 성장 단계
    static func currentStage(totalHours: Double) -> GrowthStage {
        for stage in GrowthStage.allCases.reversed() {
            if totalHours >= stage.thresholdHours {
                return stage
            }
        }
        return .seed
    }

    /// 현재 단계 내 진행률 (0.0 ~ 1.0)
    static func progress(totalHours: Double) -> Double {
        let stage = currentStage(totalHours: totalHours)
        guard let next = stage.nextThresholdHours else { return 1.0 }

        let current = stage.thresholdHours
        let range = next - current
        guard range > 0 else { return 1.0 }

        return min(1.0, (totalHours - current) / range)
    }

    /// 다음 단계까지 남은 시간 (hours)
    static func hoursToNextStage(totalHours: Double) -> Double? {
        let stage = currentStage(totalHours: totalHours)
        guard let next = stage.nextThresholdHours else { return nil }
        return max(0, next - totalHours)
    }
}
