import Foundation
import SwiftData
import os

// MARK: - 스케줄 매니저 (v1.3)
// 요일별 자동 집중 세션 시작/종료 관리

@MainActor
@Observable
final class ScheduleManager {
    static let shared = ScheduleManager()

    private(set) var isMonitoring = false
    private var checkTimer: Timer?

    /// 의존성 (configure 시 설정)
    private var modelContext: ModelContext?
    private var appState: AppState?

    /// 오늘 이미 트리거된 스케줄 ID 추적 (재트리거 방지)
    private var triggeredToday: [PersistentIdentifier: Date] = [:]

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "ScheduleManager"
    )

    // MARK: - 초기 설정

    /// 앱 시작 시 1회 호출 — 의존성 주입
    func configure(modelContext: ModelContext, appState: AppState) {
        self.modelContext = modelContext
        self.appState = appState
    }

    // MARK: - 모니터링

    /// 스케줄 체크 시작
    func startMonitoring() {
        guard !isMonitoring else { return }
        guard modelContext != nil, appState != nil else {
            logger.warning("ScheduleManager 미설정 — configure() 먼저 호출 필요")
            return
        }

        isMonitoring = true
        logger.info("스케줄 모니터링 시작")

        checkTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.Schedule.checkIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSchedules()
            }
        }

        // 즉시 1회 체크
        checkSchedules()
    }

    /// 모니터링 중지
    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
        isMonitoring = false
        triggeredToday.removeAll()
        logger.info("스케줄 모니터링 중지")
    }

    /// 외부에서 즉시 스케줄 재확인 요청 (세션 중지 후 재참여 배너 즉시 표시용)
    func checkSchedulesNow() {
        guard isMonitoring else { return }
        checkSchedules()
    }

    // MARK: - 스케줄 체크

    private func checkSchedules() {
        guard let modelContext, let appState else { return }

        let now = Date()
        let calendar = Calendar.current

        // 자정이 지났으면 트리거 이력 초기화
        cleanupTriggeredHistory(calendar: calendar, now: now)

        let currentWeekday = calendar.component(.weekday, from: now)
        let currentMinute = calendar.component(.hour, from: now) * 60
            + calendar.component(.minute, from: now)

        // 활성 스케줄 가져오기
        let descriptor = FetchDescriptor<BlockSchedule>(
            predicate: #Predicate<BlockSchedule> { $0.isEnabled }
        )
        guard let schedules = try? modelContext.fetch(descriptor) else { return }

        var foundRejoin: AppState.PendingScheduleInfo?

        for schedule in schedules {
            let weekdays = schedule.weekdayArray

            guard weekdays.contains(currentWeekday) else { continue }

            let isInTimeRange: Bool
            if schedule.startMinuteOfDay <= schedule.endMinuteOfDay {
                isInTimeRange = currentMinute >= schedule.startMinuteOfDay
                    && currentMinute < schedule.endMinuteOfDay
            } else {
                isInTimeRange = currentMinute >= schedule.startMinuteOfDay
                    || currentMinute < schedule.endMinuteOfDay
            }

            // 오늘 이미 트리거했으면 → 재참여 후보로 등록
            if triggeredToday[schedule.persistentModelID] != nil {
                if isInTimeRange && appState.focusState == .idle,
                   let profile = schedule.profile {
                    foundRejoin = AppState.PendingScheduleInfo(
                        scheduleName: schedule.name,
                        profileID: profile.persistentModelID,
                        endMinuteOfDay: schedule.endMinuteOfDay,
                        endTimeFormatted: schedule.endTimeFormatted
                    )
                }
                continue
            }

            if isInTimeRange && appState.focusState == .idle {
                guard let profile = schedule.profile else {
                    logger.warning("스케줄 '\(schedule.name, privacy: .public)' 프로필 미연결 — 건너뜀")
                    continue
                }

                // 남은 시간 계산 (초 단위 정밀도)
                let currentSecondOfDay = calendar.component(.hour, from: now) * 3600
                    + calendar.component(.minute, from: now) * 60
                    + calendar.component(.second, from: now)
                let endSecondOfDay = schedule.endMinuteOfDay * 60

                let remainingSeconds: Int
                if currentSecondOfDay < endSecondOfDay {
                    remainingSeconds = endSecondOfDay - currentSecondOfDay
                } else {
                    // 자정 넘김
                    remainingSeconds = (24 * 3600 - currentSecondOfDay) + endSecondOfDay
                }
                let duration = TimeInterval(max(remainingSeconds, 1))

                logger.info("스케줄 '\(schedule.name, privacy: .public)' 매칭 — 남은 \(remainingSeconds)초, 자동 세션 시작")
                triggeredToday[schedule.persistentModelID] = now

                Task {
                    await appState.startSessionFromProfile(
                        profile,
                        modelContext: modelContext,
                        durationOverride: duration,
                        scheduleName: schedule.name,
                        endMinuteOfDay: schedule.endMinuteOfDay
                    )
                }
                return
            }
        }

        // 재참여 가능 스케줄 업데이트
        appState.pendingScheduleRejoin = foundRejoin
    }

    /// 자정이 지나면 트리거 이력 초기화
    private func cleanupTriggeredHistory(calendar: Calendar, now: Date) {
        guard !triggeredToday.isEmpty else { return }

        let startOfToday = calendar.startOfDay(for: now)
        let staleKeys = triggeredToday.filter { $0.value < startOfToday }.map(\.key)
        for key in staleKeys {
            triggeredToday.removeValue(forKey: key)
        }
    }
}
