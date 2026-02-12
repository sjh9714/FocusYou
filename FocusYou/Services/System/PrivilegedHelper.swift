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

        // 스크립트 내 특수문자 이스케이프
        let escapedScript = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let appleScript = "do shell script \"\(escapedScript)\" with administrator privileges"

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

        // 임시 파일에 내용 쓰기
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("focusyou_temp_\(UUID().uuidString)")
            .path

        guard FileManager.default.createFile(
            atPath: tempPath,
            contents: content.data(using: .utf8)
        ) else {
            logger.error("임시 파일 생성 실패")
            throw FocusYouError.hostsFileWriteFailed
        }

        defer {
            try? FileManager.default.removeItem(atPath: tempPath)
        }

        // hosts 파일 쓰기 + DNS 플러시를 하나의 admin 스크립트로 통합
        // → 비밀번호 다이얼로그 1회만 등장
        let script = "cp \(tempPath) \(path) && chmod 644 \(path) && dscacheutil -flushcache && killall -HUP mDNSResponder"
        _ = try await executeAsAdmin(script: script)
    }
}
