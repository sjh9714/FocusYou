import Foundation
import SwiftData

extension AppState {
    /// 취소 가능 여부 (취소 강도별 로직)
    var canCancel: Bool {
        switch currentCancelIntensity {
        case 0:
            return true
        case 1:
            return cancelLockoutRemainingSeconds <= 0
        default:
            return false
        }
    }

    /// Level 1: 잠금 남은 시간 (초)
    var cancelLockoutRemainingSeconds: TimeInterval {
        guard currentCancelIntensity == 1,
              let startedAt = sessionStartedAt else { return 0 }
        let elapsed = Date().timeIntervalSince(startedAt)
        let lockoutSeconds = TimeInterval(currentCancelLockoutMinutes * 60)
        return max(0, lockoutSeconds - elapsed)
    }

    /// Level 2: 오늘 비상 해제 사용 여부
    var emergencyUnlockUsedToday: Bool {
        guard let lastUsed = UserDefaults.standard.object(
            forKey: "emergencyUnlockLastUsedDate"
        ) as? Date else { return false }
        return Calendar.current.isDateInToday(lastUsed)
    }

    /// Level 2: 비상 해제 요청 (2분 카운트다운 시작)
    func requestEmergencyUnlock() {
        guard currentCancelIntensity >= 2,
              !emergencyUnlockUsedToday else { return }

        isEmergencyUnlockActive = true
        emergencyUnlockCountdown = Constants.CancelIntensity.emergencyUnlockDuration

        emergencyUnlockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.emergencyUnlockCountdown -= 1
                if self.emergencyUnlockCountdown <= 0 {
                    self.emergencyUnlockTimer?.invalidate()
                    self.emergencyUnlockTimer = nil
                }
            }
        }

        logger.info("비상 해제 카운트다운 시작")
    }

    /// 비상 해제 카운트다운 취소
    func cancelEmergencyUnlock() {
        emergencyUnlockTimer?.invalidate()
        emergencyUnlockTimer = nil
        isEmergencyUnlockActive = false
        emergencyUnlockCountdown = 0
        logger.info("비상 해제 취소")
    }

    /// 비상 해제 확인 (카운트다운 완료 후 세션 중지)
    func confirmEmergencyUnlock(modelContext: ModelContext) async {
        guard currentCancelIntensity >= 2,
              emergencyUnlockCountdown <= 0,
              isEmergencyUnlockActive else { return }

        UserDefaults.standard.set(Date(), forKey: "emergencyUnlockLastUsedDate")
        isEmergencyUnlockActive = false
        emergencyUnlockTimer?.invalidate()
        emergencyUnlockTimer = nil

        logger.info("비상 해제 확인 — 세션 강제 중지")
        await stopSession(modelContext: modelContext)
    }

    /// 취소 강도 상태 초기화
    func resetCancelIntensityState() {
        sessionStartedAt = nil
        currentCancelIntensity = 0
        currentCancelLockoutMinutes = 0
        emergencyUnlockCountdown = 0
        isEmergencyUnlockActive = false
        emergencyUnlockTimer?.invalidate()
        emergencyUnlockTimer = nil
    }
}
