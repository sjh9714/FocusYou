import Foundation
import os

// MARK: - hosts 파일 관리자
// /etc/hosts 파일의 마커 구간을 관리하여 웹사이트 차단 수행

actor HostsFileManager {
    static let shared = HostsFileManager()

    private let hostsPath = Constants.Blocking.hostsFilePath
    private let backupPath = Constants.Blocking.hostsBackupPath
    private let beginMarker = Constants.Blocking.beginMarker
    private let endMarker = Constants.Blocking.endMarker
    private let redirectIP = Constants.Blocking.redirectIP

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "HostsFile"
    )

    // MARK: - 읽기 (권한 불필요)

    /// hosts 파일 내용 읽기
    func readHostsFile() throws -> String {
        guard let content = try? String(contentsOfFile: hostsPath, encoding: .utf8) else {
            logger.error("hosts 파일 읽기 실패")
            throw FocusYouError.hostsFileReadFailed
        }
        return content
    }

    /// 마커 구간이 존재하는지 확인 (활성 차단 여부)
    func hasActiveBlocking() -> Bool {
        guard let content = try? readHostsFile() else {
            return false
        }
        return content.contains(beginMarker)
    }

    // MARK: - 백업

    /// hosts 파일 백업 (차단 시작 전 호출)
    func backupHostsFile() throws {
        logger.info("hosts 파일 백업 시작")
        let content = try readHostsFile()
        try content.write(toFile: backupPath, atomically: true, encoding: .utf8)
        logger.info("hosts 파일 백업 완료: \(self.backupPath)")
    }

    // MARK: - 차단 도메인 추가

    /// 마커 구간에 차단 도메인 추가
    /// 기존 마커 구간이 있으면 교체, 없으면 파일 끝에 추가
    func buildBlockedContent(domains: [String]) throws -> String {
        var content = try readHostsFile()

        // 기존 마커 구간 제거
        content = removeMarkerSection(from: content)

        // 차단 항목 생성
        var blockEntries = [String]()
        blockEntries.append("")
        blockEntries.append(beginMarker)

        for domain in domains {
            let normalized = domain.normalizedDomain
            guard !normalized.isEmpty else { continue }

            // 도메인 자체와 www 서브도메인 모두 차단
            blockEntries.append("\(redirectIP) \(normalized)")
            if !normalized.hasPrefix("www.") {
                blockEntries.append("\(redirectIP) www.\(normalized)")
            }
        }

        blockEntries.append(endMarker)
        blockEntries.append("")

        content += blockEntries.joined(separator: "\n")
        return content
    }

    /// 마커 구간 제거된 내용 생성
    func buildCleanContent() throws -> String {
        let content = try readHostsFile()
        return removeMarkerSection(from: content)
    }

    // MARK: - Private

    /// 마커 구간을 문자열에서 제거
    private func removeMarkerSection(from content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var result = [String]()
        var isInMarkerSection = false

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == beginMarker {
                isInMarkerSection = true
                continue
            }
            if line.trimmingCharacters(in: .whitespaces) == endMarker {
                isInMarkerSection = false
                continue
            }
            if !isInMarkerSection {
                result.append(line)
            }
        }

        // 끝부분 빈 줄 정리
        while let last = result.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            result.removeLast()
        }

        return result.joined(separator: "\n") + "\n"
    }
}
