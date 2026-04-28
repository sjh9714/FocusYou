import Foundation
import SwiftData

extension AppState {
    /// 프로필의 타이머 설정으로 즉시 세션 시작
    /// - Parameters:
    ///   - durationOverride: 스케줄에서 호출 시 남은 시간(초)으로 덮어쓰기
    ///   - scheduleName: 스케줄에서 호출 시 스케줄 이름 (배너 표시용)
    ///   - endMinuteOfDay: 스케줄 종료 시각 (분 단위, 재개 시 실시간 조정용)
    func startSessionFromProfile(
        _ profile: BlockProfile,
        modelContext: ModelContext,
        durationOverride: TimeInterval? = nil,
        scheduleName: String? = nil,
        endMinuteOfDay: Int? = nil
    ) async {
        setActiveProfile(profile)
        activeScheduleName = scheduleName
        scheduleEndMinuteOfDay = endMinuteOfDay
        let input = profileSessionMapper.makeInput(
            from: profile,
            durationOverride: durationOverride
        )

        if input.sites.isEmpty && input.apps.isEmpty {
            logger.warning("프로필 '\(profile.name, privacy: .public)'에 활성 차단 항목 없음 — 타이머만 시작")
        }

        await startFocusSession(
            duration: input.duration,
            sites: input.sites,
            apps: input.apps,
            modelContext: modelContext,
            mode: input.mode,
            pomodoroConfiguration: input.pomodoroConfiguration,
            blocklistMode: input.blocklistMode,
            cancelIntensity: input.cancelIntensity,
            cancelLockoutMinutes: input.cancelLockoutMinutes
        )

        currentSession?.profileName = profile.name
    }

    /// 진행 중인 스케줄에 재참여
    func rejoinPendingSchedule(modelContext: ModelContext) async {
        guard let info = pendingScheduleRejoin else { return }

        guard let profile = modelContext.model(for: info.profileID) as? BlockProfile else {
            logger.warning("스케줄 재참여 실패: 프로필 찾을 수 없음")
            return
        }

        let remainingSeconds = timingCalculator.secondsUntilScheduleEnd(endMinuteOfDay: info.endMinuteOfDay)
        logger.info("스케줄 '\(info.scheduleName, privacy: .public)' 재참여 — 남은 \(Int(remainingSeconds))초")

        pendingScheduleRejoin = nil
        await startSessionFromProfile(
            profile,
            modelContext: modelContext,
            durationOverride: remainingSeconds,
            scheduleName: info.scheduleName,
            endMinuteOfDay: info.endMinuteOfDay
        )
    }

    func setActiveProfile(_ profile: BlockProfile?) {
        activeProfileID = profile?.persistentModelID
    }

    func ensureActiveProfile(in profiles: [BlockProfile]) {
        guard !profiles.isEmpty else {
            activeProfileID = nil
            return
        }

        if let activeProfileID,
           profiles.contains(where: { $0.persistentModelID == activeProfileID }) {
            return
        }

        if let defaultProfile = profiles.first(where: \.isDefault) {
            activeProfileID = defaultProfile.persistentModelID
            return
        }

        activeProfileID = profiles.first?.persistentModelID
    }

    func activeProfile(from profiles: [BlockProfile]) -> BlockProfile? {
        guard let activeProfileID else { return nil }
        return profiles.first(where: { $0.persistentModelID == activeProfileID })
    }
}
