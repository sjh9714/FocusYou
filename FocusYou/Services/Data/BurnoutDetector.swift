import Foundation
import os

// MARK: - 번아웃 방지 서비스 (v1.5)

@MainActor
@Observable
final class BurnoutDetector {
    static let shared = BurnoutDetector()

    private let defaults = UserDefaults.standard
    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "BurnoutDetector"
    )

    // MARK: - 번아웃 상태

    enum BurnoutStatus: Equatable {
        case safe
        case approaching(remainingMinutes: Int)
        case exceeded(overageMinutes: Int)
    }

    // MARK: - 배너 상태

    private(set) var showBanner = false
    private(set) var bannerMessage = ""

    /// 스트레칭 알림 발송 여부 (세션당 1회)
    private var stretchReminderSentThisSession = false

    // MARK: - 번아웃 상태 확인

    /// 오늘 총 집중 시간(초) 기반 번아웃 상태 판정
    func checkBurnoutStatus(todayFocusSeconds: Int, dailyLimitHours: Double) -> BurnoutStatus {
        let limitSeconds = dailyLimitHours * 3600
        let remaining = limitSeconds - Double(todayFocusSeconds)
        let remainingMinutes = Int(remaining / 60)

        if remaining <= 0 {
            return .exceeded(overageMinutes: Int(abs(remaining) / 60))
        } else if remaining <= Constants.Burnout.approachingThresholdSeconds {
            return .approaching(remainingMinutes: max(remainingMinutes, 1))
        }
        return .safe
    }

    /// 번아웃 배너 업데이트 (세션 시작/타이머 갱신 시 호출)
    func updateBanner(todayFocusSeconds: Int, dailyLimitHours: Double) {
        guard isEnabled else {
            showBanner = false
            return
        }

        // 24시간 내 해제한 경우 미표시
        if let dismissed = defaults.object(forKey: Constants.Burnout.bannerDismissedAtKey) as? Date {
            if Date().timeIntervalSince(dismissed) < Constants.Burnout.bannerCooldownSeconds {
                showBanner = false
                return
            }
        }

        let status = checkBurnoutStatus(
            todayFocusSeconds: todayFocusSeconds,
            dailyLimitHours: dailyLimitHours
        )

        switch status {
        case .safe:
            showBanner = false
        case .approaching(let minutes):
            bannerMessage = String(localized: "burnout_approaching \(minutes)")
            showBanner = true
        case .exceeded(let minutes):
            bannerMessage = String(localized: "burnout_exceeded \(minutes)")
            showBanner = true
        }
    }

    /// 배너 해제 (24시간 미표시)
    func dismissBanner() {
        showBanner = false
        defaults.set(Date(), forKey: Constants.Burnout.bannerDismissedAtKey)
        logger.info("번아웃 배너 해제됨")
    }

    // MARK: - 균형 점수

    /// 최근 7일 집중:휴식 비율 기반 균형 점수 (0-100)
    func calculateBalanceScore(sessions: [FocusSessionData]) -> Int {
        guard !sessions.isEmpty else { return 100 }

        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let recent = sessions.filter { $0.startedAt >= weekAgo }
        guard !recent.isEmpty else { return 100 }

        let focusSeconds = recent
            .filter { $0.sessionType == "focus" }
            .reduce(0) { $0 + $1.actualDuration }
        let breakSeconds = recent
            .filter { $0.sessionType != "focus" }
            .reduce(0) { $0 + $1.actualDuration }

        guard focusSeconds > 0 else { return 100 }

        // 이상적 비율: 집중 5 : 휴식 1
        let idealRatio = 0.2
        let actualRatio = Double(breakSeconds) / Double(focusSeconds)

        // 0에 가까울수록 (휴식 전혀 안 함) 점수 낮음
        // idealRatio에 가까울수록 100점
        let deviation = abs(actualRatio - idealRatio)
        let score = max(0, Int(100 - deviation * 200))
        return min(100, score)
    }

    // MARK: - 스트레칭 알림

    /// 90분 연속 집중 시 스트레칭 알림 필요 여부
    func shouldShowStretchReminder(elapsedSeconds: TimeInterval) -> Bool {
        guard isEnabled, !stretchReminderSentThisSession else { return false }
        return elapsedSeconds >= Constants.Burnout.stretchReminderThresholdSeconds
    }

    /// 스트레칭 알림 발송 완료 마킹
    func markStretchReminderSent() {
        stretchReminderSentThisSession = true
    }

    /// 세션 리셋 (새 세션 시작 시)
    func resetSession() {
        stretchReminderSentThisSession = false
    }

    // MARK: - Private

    private var isEnabled: Bool {
        guard defaults.object(forKey: Constants.Settings.enableBurnoutWarningsKey) != nil else {
            return Constants.Settings.enableBurnoutWarningsDefault
        }
        return defaults.bool(forKey: Constants.Settings.enableBurnoutWarningsKey)
    }
}

// MARK: - 세션 데이터 (SwiftData 비의존)

struct FocusSessionData {
    let startedAt: Date
    let actualDuration: Int
    let sessionType: String
}
