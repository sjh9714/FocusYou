import AppKit
import Foundation
import os

// MARK: - macOS Focus Mode 연동 (v1.4)
// 세션 시작 시 시스템 방해금지(DND) 활성화, 세션 종료 시 비활성화
// macOS 13+ Shortcuts CLI 기반: "FocusYou DND On" / "FocusYou DND Off" 단축어 실행

@MainActor
final class FocusModeController {
    static let shared = FocusModeController()

    private let dndOnName = "FocusYou DND On"
    private let dndOffName = "FocusYou DND Off"

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "FocusModeController"
    )

    /// DND 활성화 여부 추적 (앱 종료 시 정리용)
    private(set) var isDNDActivatedByApp = false

    /// Shortcuts 설치 여부
    private(set) var isSetupComplete = false

    private init() {}

    // MARK: - Public

    /// 단축어가 설치되어 있는지 확인
    func checkSetup() async -> Bool {
        let output = await runShellWithOutput("shortcuts list")
        let hasOn = output.contains(dndOnName)
        let hasOff = output.contains(dndOffName)
        isSetupComplete = hasOn && hasOff
        logger.info("Shortcuts 설치 확인: on=\(hasOn), off=\(hasOff)")
        return isSetupComplete
    }

    /// 기존 단축어 삭제 후 재설치
    func performSetup() async {
        // 기존 단축어 삭제 (잘못된 버전이 있을 수 있음)
        await runShell("shortcuts delete \"\(dndOnName)\" 2>/dev/null")
        await runShell("shortcuts delete \"\(dndOffName)\" 2>/dev/null")
        logger.info("기존 단축어 삭제 완료")

        let tmpDir = FileManager.default.temporaryDirectory

        // ON 단축어 생성 (shortcuts sign은 .shortcut 확장자 필수)
        let onUnsignedURL = tmpDir.appendingPathComponent("FocusYouDNDOn_unsigned.shortcut")
        let onSignedURL = tmpDir.appendingPathComponent("FocusYou DND On.shortcut")
        createShortcutPlist(enabled: true, at: onUnsignedURL)
        await signShortcut(input: onUnsignedURL, output: onSignedURL)

        // OFF 단축어 생성
        let offUnsignedURL = tmpDir.appendingPathComponent("FocusYouDNDOff_unsigned.shortcut")
        let offSignedURL = tmpDir.appendingPathComponent("FocusYou DND Off.shortcut")
        createShortcutPlist(enabled: false, at: offUnsignedURL)
        await signShortcut(input: offUnsignedURL, output: offSignedURL)

        // ON 단축어 열기 (Shortcuts.app 임포트)
        if FileManager.default.fileExists(atPath: onSignedURL.path) {
            NSWorkspace.shared.open(onSignedURL)
            logger.info("DND On 단축어 임포트 요청")
        }

        // 잠시 대기 후 OFF 단축어 열기
        try? await Task.sleep(for: .seconds(2))

        if FileManager.default.fileExists(atPath: offSignedURL.path) {
            NSWorkspace.shared.open(offSignedURL)
            logger.info("DND Off 단축어 임포트 요청")
        }
    }

    /// 세션 시작 시 시스템 방해금지 활성화
    func activateDND() async {
        guard isEnabled else { return }

        if !isSetupComplete {
            let ready = await checkSetup()
            guard ready else {
                logger.warning("DND 단축어 미설치 — 방해금지 활성화 생략")
                return
            }
        }

        logger.info("시스템 방해금지 활성화 요청")
        await runShortcut(dndOnName)
        isDNDActivatedByApp = true
    }

    /// 세션 종료 시 시스템 방해금지 비활성화
    func deactivateDND() async {
        guard isDNDActivatedByApp else { return }

        logger.info("시스템 방해금지 비활성화 요청")
        await runShortcut(dndOffName)
        isDNDActivatedByApp = false
    }

    // MARK: - Private

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Constants.Settings.enableFocusModeKey)
    }

    /// 단축어 실행
    private func runShortcut(_ name: String) async {
        let exitCode = await runShell("shortcuts run \"\(name)\"")
        if exitCode != 0 {
            logger.warning("단축어 실행 실패: \(name), 종료코드: \(exitCode)")
        }
    }

    /// "집중 모드 설정(DND)" 액션이 포함된 .shortcut 파일 생성
    /// - Parameter enabled: true = DND 켜기, false = DND 끄기
    private func createShortcutPlist(enabled: Bool, at url: URL) {
        let plist: [String: Any] = [
            "WFWorkflowActions": [
                [
                    "WFWorkflowActionIdentifier": "is.workflow.actions.dnd.set",
                    "WFWorkflowActionParameters": [
                        "Enabled": enabled ? 1 : 0,
                        "FocusModes": [
                            "DisplayString": "Do Not Disturb",
                            "Identifier": "com.apple.donotdisturb.mode.default",
                        ] as [String: Any],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            "WFWorkflowImportQuestions": [] as [Any],
            "WFWorkflowTypes": ["NCWidget", "WatchKit"],
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowMinimumClientVersionString": "900",
        ]

        let data = try? PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .binary,
            options: 0
        )
        try? data?.write(to: url)
    }

    /// shortcuts sign 으로 서명
    private func signShortcut(input: URL, output: URL) async {
        let exitCode = await runShell(
            "shortcuts sign -m anyone -i \"\(input.path)\" -o \"\(output.path)\""
        )
        if exitCode != 0 {
            logger.warning("단축어 서명 실패: \(input.lastPathComponent)")
        }
    }

    /// 셸 명령 실행 (종료 코드 반환)
    @discardableResult
    private func runShell(_ command: String) async -> Int32 {
        let log = logger
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", command]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                log.error("셸 명령 실행 실패: \(error.localizedDescription)")
                continuation.resume(returning: -1)
            }
        }
    }

    /// 셸 명령 실행 (출력 문자열 반환)
    private func runShellWithOutput(_ command: String) async -> String {
        let log = logger
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", command]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
            do {
                try process.run()
            } catch {
                log.error("셸 명령 실행 실패: \(error.localizedDescription)")
                continuation.resume(returning: "")
            }
        }
    }
}
