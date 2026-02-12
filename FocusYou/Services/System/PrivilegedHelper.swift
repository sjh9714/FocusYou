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
    func executeAsAdmin(script: String) async throws -> String {
        logger.info("관리자 권한으로 스크립트 실행 요청")

        // 스크립트 내 특수문자 이스케이프
        let escapedScript = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let appleScript = "do shell script \"\(escapedScript)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger.error("프로세스 실행 실패: \(error.localizedDescription)")
            throw FocusYouError.authorizationFailed
        }

        let status = process.terminationStatus

        if status != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? ""
            logger.error("스크립트 실행 실패 (종료 코드: \(status)): \(errorString)")

            // 사용자 취소 감지
            if errorString.contains("User canceled") || errorString.contains("-128") {
                throw FocusYouError.authorizationCancelled
            }
            throw FocusYouError.authorizationFailed
        }

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        logger.debug("스크립트 실행 성공")
        return output
    }

    /// 관리자 권한으로 파일 쓰기 (임시 파일 → sudo mv)
    func writeFileAsRoot(content: String, to path: String) async throws {
        logger.info("관리자 권한으로 파일 쓰기: \(path)")

        // 임시 파일에 내용 쓰기
        let tempPath = "/tmp/focusyou_temp_\(UUID().uuidString)"

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

        // sudo로 파일 복사
        let script = "cp \(tempPath) \(path) && chmod 644 \(path)"
        _ = try await executeAsAdmin(script: script)
    }
}
