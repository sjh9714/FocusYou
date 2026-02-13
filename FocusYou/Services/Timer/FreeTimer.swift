import AppKit
import Foundation
import os

// MARK: - 자유 타이머
// 설정한 시간만큼 카운트다운. 절대 시간 기반으로 드리프트 방지.

@MainActor
@Observable
final class FreeTimer {

    // MARK: - 타이머 상태

    enum State: Sendable {
        case idle
        case running
        case paused
        case completed
    }

    // MARK: - Properties

    private(set) var state: State = .idle

    /// 설정된 전체 시간 (초)
    private(set) var totalDuration: TimeInterval = 0

    /// 남은 시간 (초)
    private(set) var remainingTime: TimeInterval = 0

    /// 경과 시간 (초)
    var elapsedTime: TimeInterval {
        totalDuration - remainingTime
    }

    /// 진행률 (0.0 ~ 1.0)
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return elapsedTime / totalDuration
    }

    /// 완료 시 호출되는 콜백
    var onComplete: (() -> Void)?

    // MARK: - Private

    private var timer: Timer?
    /// 타이머 시작 또는 재개 시점
    private var referenceDate: Date?
    /// 일시정지 누적 시간
    private var pauseAccumulator: TimeInterval = 0
    /// 일시정지 시작 시점
    private var pauseStartDate: Date?
    /// 시스템 슬립 시작 시점
    private var sleepStartDate: Date?
    /// 슬립/웨이크 알림 옵저버
    private var sleepObservers: [Any] = []

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "FreeTimer"
    )

    // MARK: - Public Methods

    /// 타이머 시작
    func start(duration: TimeInterval) {
        guard state == .idle else {
            logger.warning("타이머 시작 시도 실패: 현재 상태 = \(String(describing: self.state))")
            return
        }

        logger.info("타이머 시작: \(Int(duration))초")
        totalDuration = duration
        remainingTime = duration
        pauseAccumulator = 0
        referenceDate = Date()
        state = .running

        setupSleepObservers()
        startTicking()
    }

    /// 일시정지
    func pause() {
        guard state == .running else { return }
        logger.info("타이머 일시정지")
        state = .paused
        pauseStartDate = Date()
        stopTicking()
    }

    /// 재개
    func resume() {
        guard state == .paused else { return }
        logger.info("타이머 재개")

        // 일시정지 시간 누적
        if let pauseStart = pauseStartDate {
            pauseAccumulator += Date().timeIntervalSince(pauseStart)
            pauseStartDate = nil
        }

        state = .running
        startTicking()
    }

    /// 정지 (취소)
    func stop() {
        guard state == .running || state == .paused else { return }
        logger.info("타이머 정지")
        stopTicking()
        state = .idle
        resetInternal()
    }

    /// 초기 상태로 리셋
    func reset() {
        stopTicking()
        state = .idle
        resetInternal()
    }

    // MARK: - Private Methods

    private func startTicking() {
        stopTicking()
        timer = Timer.scheduledTimer(
            withTimeInterval: Constants.Timer.activeRefreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    /// 매 틱마다 호출: 절대 시간 기반으로 남은 시간 계산
    private func tick() {
        guard state == .running, let referenceDate else { return }

        let elapsed = Date().timeIntervalSince(referenceDate) - pauseAccumulator
        remainingTime = max(0, totalDuration - elapsed)

        if remainingTime <= 0 {
            logger.info("타이머 완료")
            remainingTime = 0
            state = .completed
            stopTicking()
            onComplete?()
        }
    }

    private func resetInternal() {
        totalDuration = 0
        remainingTime = 0
        pauseAccumulator = 0
        referenceDate = nil
        pauseStartDate = nil
        sleepStartDate = nil
        removeSleepObservers()
    }

    // MARK: - 시스템 슬립/웨이크 처리

    /// NSWorkspace 슬립/웨이크 알림 등록
    private func setupSleepObservers() {
        removeSleepObservers()
        let wsnc = NSWorkspace.shared.notificationCenter

        sleepObservers.append(
            wsnc.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.handleSystemSleep() }
            }
        )

        sleepObservers.append(
            wsnc.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.handleSystemWake() }
            }
        )
    }

    /// 슬립 시작: 타이머 정지 + 슬립 시점 기록
    private func handleSystemSleep() {
        guard state == .running else { return }
        logger.info("시스템 슬립 감지 — 타이머 일시중단")
        sleepStartDate = Date()
        stopTicking()
    }

    /// 웨이크: 슬립 경과 시간을 pauseAccumulator에 누적 후 타이머 재개
    private func handleSystemWake() {
        guard state == .running, let sleepStart = sleepStartDate else { return }
        let sleepDuration = Date().timeIntervalSince(sleepStart)
        pauseAccumulator += sleepDuration
        sleepStartDate = nil
        logger.info("시스템 웨이크 — 슬립 \(Int(sleepDuration))초 제외, 타이머 재개")
        startTicking()
    }

    private func removeSleepObservers() {
        let wsnc = NSWorkspace.shared.notificationCenter
        for observer in sleepObservers {
            wsnc.removeObserver(observer)
        }
        sleepObservers.removeAll()
    }
}
