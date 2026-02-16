import AVFoundation
import os

// MARK: - 앰비언트 사운드 트랙

enum AmbientSoundTrack: String, CaseIterable, Sendable {
    case whiteNoise = "whiteNoise"
    case brownNoise = "brownNoise"
    case pinkNoise = "pinkNoise"

    var displayName: String {
        switch self {
        case .whiteNoise: String(localized: "sound_white_noise")
        case .brownNoise: String(localized: "sound_brown_noise")
        case .pinkNoise: String(localized: "sound_pink_noise")
        }
    }

    var icon: String {
        switch self {
        case .whiteNoise: "waveform"
        case .brownNoise: "water.waves"
        case .pinkNoise: "waveform.path.ecg"
        }
    }
}

// MARK: - 프로토콜

protocol AmbientSoundServicing: Sendable {
    func play(track: AmbientSoundTrack, volume: Float) async
    func stop() async
    func pause() async
    func resume() async
    func setVolume(_ volume: Float) async
    var isPlaying: Bool { get async }
}

// MARK: - 앰비언트 사운드 매니저

/// AVAudioEngine 기반 프로그래밍 노이즈 생성기.
/// 미사용 시 엔진을 즉시 해제하여 리소스를 절약합니다.
actor AmbientSoundManager: AmbientSoundServicing {
    static let shared = AmbientSoundManager()

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "AmbientSound"
    )

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var currentTrack: AmbientSoundTrack?
    private(set) var isPlaying = false
    private var currentVolume: Float = 0.5

    private init() {}

    // MARK: - 공개 API

    func play(track: AmbientSoundTrack, volume: Float) async {
        // 이미 같은 트랙 재생 중이면 볼륨만 조정
        if isPlaying, currentTrack == track {
            await setVolume(volume)
            return
        }

        // 기존 재생 정리
        await stop()

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let format = AVAudioFormat(
            standardFormatWithSampleRate: Constants.Sound.sampleRate,
            channels: 1
        )
        guard let format else {
            logger.error("오디오 포맷 생성 실패")
            return
        }

        engine.connect(player, to: engine.mainMixerNode, format: format)

        guard let buffer = generateNoiseBuffer(track: track, format: format) else {
            logger.error("노이즈 버퍼 생성 실패: \(track.rawValue, privacy: .public)")
            return
        }

        do {
            try engine.start()
        } catch {
            logger.error("오디오 엔진 시작 실패: \(error.localizedDescription, privacy: .public)")
            return
        }

        player.volume = volume
        // .loops 옵션은 무한 반복이므로 async 버전(완료 대기) 대신 completionHandler 버전 사용
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()

        audioEngine = engine
        playerNode = player
        currentTrack = track
        currentVolume = volume
        isPlaying = true

        logger.info("앰비언트 사운드 재생 시작: \(track.rawValue, privacy: .public), 볼륨: \(volume)")
    }

    func stop() async {
        guard audioEngine != nil else { return }

        playerNode?.stop()
        audioEngine?.stop()

        if let player = playerNode {
            audioEngine?.detach(player)
        }

        audioEngine = nil
        playerNode = nil
        currentTrack = nil
        isPlaying = false

        logger.info("앰비언트 사운드 정지 및 엔진 해제")
    }

    func pause() async {
        guard isPlaying, let player = playerNode else { return }
        player.pause()
        isPlaying = false
        logger.info("앰비언트 사운드 일시정지")
    }

    func resume() async {
        guard !isPlaying, let player = playerNode, audioEngine != nil else { return }
        player.play()
        isPlaying = true
        logger.info("앰비언트 사운드 재개")
    }

    func setVolume(_ volume: Float) async {
        currentVolume = volume
        playerNode?.volume = volume
    }

    // MARK: - 노이즈 생성

    private func generateNoiseBuffer(
        track: AmbientSoundTrack,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(format.sampleRate * 2) // 2초 버퍼
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else { return nil }

        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        switch track {
        case .whiteNoise:
            generateWhiteNoise(into: channelData, frameCount: Int(frameCount))
        case .brownNoise:
            generateBrownNoise(into: channelData, frameCount: Int(frameCount))
        case .pinkNoise:
            generatePinkNoise(into: channelData, frameCount: Int(frameCount))
        }

        return buffer
    }

    /// White noise: 균등분포 랜덤 샘플
    private func generateWhiteNoise(into buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            buffer[i] = Float.random(in: -0.5...0.5)
        }
    }

    /// Brown noise: 랜덤 워크 (이전 샘플에 소량 누적)
    private func generateBrownNoise(into buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        var lastValue: Float = 0
        let step: Float = 0.02

        for i in 0..<frameCount {
            lastValue += Float.random(in: -step...step)
            lastValue = max(-1.0, min(1.0, lastValue))
            buffer[i] = lastValue * 0.5
        }
    }

    /// Pink noise: Voss-McCartney 알고리즘 (16-octave band 합산)
    private func generatePinkNoise(into buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        let octaves = 16
        var octaveValues = [Float](repeating: 0, count: octaves)
        var runningSum: Float = 0

        // 초기값 설정
        for i in 0..<octaves {
            let value = Float.random(in: -1...1)
            octaveValues[i] = value
            runningSum += value
        }

        let normalizationFactor: Float = 1.0 / Float(octaves)

        for i in 0..<frameCount {
            // 각 옥타브는 2^n 간격으로 갱신
            for octave in 0..<octaves {
                let interval = 1 << octave
                if i % interval == 0 {
                    runningSum -= octaveValues[octave]
                    let newValue = Float.random(in: -1...1)
                    octaveValues[octave] = newValue
                    runningSum += newValue
                }
            }

            buffer[i] = runningSum * normalizationFactor * 0.5
        }
    }
}
