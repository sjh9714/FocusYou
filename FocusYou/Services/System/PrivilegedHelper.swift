import Foundation
import os

// MARK: - 관리자 권한 헬퍼
// osascript를 사용하여 macOS 기본 비밀번호 다이얼로그를 통해 관리자 권한 획득

actor PrivilegedHelper {
    static let shared = PrivilegedHelper()

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "PrivilegedHelper"
    )

    /// 관리자 권한으로 셸 스크립트 실행
    /// osascript "do shell script ... with administrator privileges" 방식 사용
    /// 블로킹 호출을 백그라운드 스레드에서 실행하여 actor 데드락 방지
    func executeAsAdmin(script: String) async throws -> String {
        logger.info("관리자 권한으로 스크립트 실행 요청")
        logger.debug("실행할 스크립트: \(script)")

        // 스크립트 내 특수문자 이스케이프 (AppleScript 문자열 내에서 안전하게)
        let escapedScript = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let appleScript = "do shell script \"\(escapedScript)\" with administrator privileges"
        logger.debug("AppleScript: \(appleScript)")

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [logger] in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", appleScript]

                let pipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = pipe
                process.standardError = errorPipe

                do {
                    try process.run()
                } catch {
                    logger.error("프로세스 실행 실패: \(error.localizedDescription)")
                    continuation.resume(throwing: FocusYouError.authorizationFailed)
                    return
                }

                // 백그라운드 스레드에서 블로킹 대기 (actor 스레드 점유 안 함)
                process.waitUntilExit()

                let status = process.terminationStatus

                if status != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? ""
                    logger.error("스크립트 실행 실패 (종료 코드: \(status)): \(errorString)")

                    // 사용자 취소 감지
                    if errorString.contains("User canceled") || errorString.contains("-128") {
                        continuation.resume(throwing: FocusYouError.authorizationCancelled)
                    } else {
                        continuation.resume(throwing: FocusYouError.authorizationFailed)
                    }
                    return
                }

                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                logger.debug("스크립트 실행 성공")
                continuation.resume(returning: output)
            }
        }
    }

    /// 관리자 권한으로 파일 쓰기 + DNS 플러시 (단일 admin 호출)
    func writeFileAsRootAndFlushDNS(content: String, to path: String) async throws {
        logger.info("관리자 권한으로 파일 쓰기 + DNS 플러시: \(path)")

        let tempPath = writeTempFile(content: content)

        guard let tempPath else {
            throw FocusYouError.hostsFileWriteFailed
        }

        defer {
            try? FileManager.default.removeItem(atPath: tempPath)
        }

        // hosts 파일 쓰기 + DNS 플러시를 하나의 admin 스크립트로 통합
        // → 비밀번호 다이얼로그 1회만 등장
        // macOS 26+: HUP 후 SIGTERM으로 mDNSResponder 완전 재시작 (launchd 자동 복구)
        // 경로 내 쉘 특수문자 이스케이프 (backtick, dollar 방어)
        let safeTempPath = shellEscapeForDoubleQuotes(tempPath)
        let safePath = shellEscapeForDoubleQuotes(path)
        let script = "cp \"\(safeTempPath)\" \"\(safePath)\" && chmod 644 \"\(safePath)\" && dscacheutil -flushcache && killall -HUP mDNSResponder && sleep 1 && (killall mDNSResponder 2>/dev/null || true)"
        _ = try await executeAsAdmin(script: script)
    }

    // MARK: - 영구 헬퍼 (비밀번호 최초 1회)

    /// 헬퍼 스크립트 + sudoers 엔트리 유효성 검증 → 실패 시 admin 호출로 설치
    /// 최초 1회만 비밀번호 필요, 이후 영구 사용
    func ensureHelperInstalled() async throws {
        let helperPath = Constants.Blocking.helperPath
        let sudoersPath = Constants.Blocking.sudoersPath

        // 설치/권한/비밀번호 없는 실행 가능 여부까지 확인
        if isHelperInstallationValid(helperPath: helperPath, sudoersPath: sudoersPath) {
            logger.info("헬퍼 설치 검증 통과, 스킵")
            return
        }

        logger.info("헬퍼 미설치/손상 감지 → admin 권한으로 설치 시작")

        let username = ProcessInfo.processInfo.userName

        // 1. 헬퍼 스크립트 → 임시 파일
        let helperScript = """
        #!/bin/bash
        [ -f "$1" ] || exit 1
        cp "$1" /etc/hosts
        chmod 644 /etc/hosts
        dscacheutil -flushcache
        killall -HUP mDNSResponder
        sleep 1
        killall mDNSResponder 2>/dev/null || true
        """
        guard let tempHelperPath = writeTempFile(content: helperScript) else {
            throw FocusYouError.hostsFileWriteFailed
        }

        // 2. sudoers 엔트리 → 임시 파일
        let sudoersContent = "\(username) ALL=(ALL) NOPASSWD: \(helperPath)\n"
        guard let tempSudoersPath = writeTempFile(content: sudoersContent) else {
            try? FileManager.default.removeItem(atPath: tempHelperPath)
            throw FocusYouError.hostsFileWriteFailed
        }

        defer {
            try? FileManager.default.removeItem(atPath: tempHelperPath)
            try? FileManager.default.removeItem(atPath: tempSudoersPath)
        }

        // 단일 admin 스크립트: 헬퍼 + sudoers 설치
        let script = [
            "mkdir -p /usr/local/bin",
            "cp \"\(tempHelperPath)\" \"\(helperPath)\"",
            "chown root:wheel \"\(helperPath)\"",
            "chmod 755 \"\(helperPath)\"",
            "cp \"\(tempSudoersPath)\" \"\(sudoersPath)\"",
            "chmod 440 \"\(sudoersPath)\"",
            "chown root:wheel \"\(sudoersPath)\"",
            "visudo -c -f \"\(sudoersPath)\" || (rm -f \"\(sudoersPath)\" && exit 1)",
        ].joined(separator: " && ")

        _ = try await executeAsAdmin(script: script)

        guard isHelperInstallationValid(helperPath: helperPath, sudoersPath: sudoersPath) else {
            logger.error("헬퍼 설치 후 검증 실패")
            throw FocusYouError.authorizationFailed
        }

        logger.info("헬퍼 설치 완료 (이후 비밀번호 불필요)")
    }

    /// 헬퍼를 통해 비밀번호 없이 hosts 파일 변경 + DNS 플러시
    /// content를 임시 파일에 쓰고 `sudo -n focusyou-helper tempfile` 실행
    func writeHostsViaHelper(content: String) async throws {
        logger.info("헬퍼를 통해 hosts 파일 변경 시도")

        let helperPath = Constants.Blocking.helperPath

        guard let tempPath = writeTempFile(content: content) else {
            throw FocusYouError.hostsFileWriteFailed
        }

        defer {
            try? FileManager.default.removeItem(atPath: tempPath)
        }

        try await runSudoNonInteractive(arguments: [helperPath, tempPath])
        logger.info("헬퍼를 통해 hosts 파일 변경 완료")
    }

    /// sudo -n (비밀번호 없이) 명령 실행
    /// 실패 시 throw → 호출측에서 admin fallback 처리
    private func runSudoNonInteractive(arguments: [String]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [logger] in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                process.arguments = ["-n"] + arguments

                let errorPipe = Pipe()
                process.standardError = errorPipe
                process.standardOutput = FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    logger.error("sudo 프로세스 실행 실패: \(error.localizedDescription)")
                    continuation.resume(throwing: FocusYouError.hostsFileWriteFailed)
                    return
                }

                process.waitUntilExit()

                if process.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? ""
                    logger.warning("sudo -n 실패 (종료 코드: \(process.terminationStatus)): \(errorString)")
                    continuation.resume(throwing: FocusYouError.hostsFileWriteFailed)
                    return
                }

                continuation.resume()
            }
        }
    }

    // MARK: - Private

    /// 헬퍼 설치 상태 검증
    private func isHelperInstallationValid(helperPath: String, sudoersPath: String) -> Bool {
        guard FileManager.default.fileExists(atPath: helperPath),
              FileManager.default.fileExists(atPath: sudoersPath) else {
            return false
        }

        guard FileManager.default.isExecutableFile(atPath: helperPath) else {
            logger.warning("헬퍼 실행 권한 없음: \(helperPath)")
            return false
        }

        guard canRunHelperWithoutPassword(helperPath: helperPath) else {
            logger.warning("헬퍼 NOPASSWD 검증 실패")
            return false
        }

        return true
    }

    /// `sudo -n -l <helperPath>`로 비밀번호 없는 실행 권한 확인
    private func canRunHelperWithoutPassword(helperPath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "-l", helperPath]
        process.standardOutput = FileHandle.nullDevice

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger.warning("헬퍼 권한 검증 실행 실패: \(error.localizedDescription)")
            return false
        }

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? ""
            logger.warning("헬퍼 권한 검증 실패 (종료 코드: \(process.terminationStatus)): \(errorString)")
            return false
        }

        return true
    }

    /// double-quote 쉘 문자열 내 특수문자 이스케이프 (backtick, dollar)
    func shellEscapeForDoubleQuotes(_ value: String) -> String {
        value
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
    }

    /// 임시 파일 생성 헬퍼
    private func writeTempFile(content: String) -> String? {
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("focusyou_temp_\(UUID().uuidString)")
            .path

        guard FileManager.default.createFile(
            atPath: tempPath,
            contents: content.data(using: .utf8)
        ) else {
            logger.error("임시 파일 생성 실패: \(tempPath)")
            return nil
        }

        return tempPath
    }
}
