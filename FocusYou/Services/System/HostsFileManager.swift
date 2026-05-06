import Foundation
import os

#if APPSTORE
actor HostsFileManager {
    static let shared = HostsFileManager()

    init(
        hostsPath: String = Constants.Blocking.hostsFilePath,
        backupPath: String = Constants.Blocking.hostsBackupPath,
        beginMarker: String = Constants.Blocking.beginMarker,
        endMarker: String = Constants.Blocking.endMarker,
        redirectIP: String = Constants.Blocking.redirectIP
    ) {}

    func readHostsFile() throws -> String {
        throw FocusYouError.hostsFileReadFailed
    }

    func hasActiveBlocking() -> Bool {
        false
    }

    func backupHostsFile() throws {}

    func buildBlockedContent(domains: [String]) throws -> String {
        throw FocusYouError.hostsFileWriteFailed
    }

    func buildCleanContent() throws -> String {
        ""
    }

    nonisolated func expandKeywordPattern(_ keyword: String) -> [String] {
        let tlds = ["com", "net", "org", "io", "co"]
        let normalized = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        return tlds.map { "\(normalized).\($0)" }
    }

    func buildAllowlistContent(allowedDomains: [String], bundle: Bundle = .main) throws -> String {
        throw FocusYouError.hostsFileWriteFailed
    }
}
#else

// MARK: - hosts 파일 관리자
// /etc/hosts 파일의 마커 구간을 관리하여 웹사이트 차단 수행
// NOTE: 파일 I/O는 의도적으로 동기식 — /etc/hosts는 <1KB이며 sub-millisecond 완료.
// actor 격리가 스레드 안전을 보장하므로 async 전환 대비 복잡도 증가가 정당화되지 않음.

actor HostsFileManager {
    static let shared = HostsFileManager()

    private let hostsPath: String
    private let backupPath: String
    private let beginMarker: String
    private let endMarker: String
    private let redirectIP: String

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "HostsFile"
    )

    init(
        hostsPath: String = Constants.Blocking.hostsFilePath,
        backupPath: String = Constants.Blocking.hostsBackupPath,
        beginMarker: String = Constants.Blocking.beginMarker,
        endMarker: String = Constants.Blocking.endMarker,
        redirectIP: String = Constants.Blocking.redirectIP
    ) {
        self.hostsPath = hostsPath
        self.backupPath = backupPath
        self.beginMarker = beginMarker
        self.endMarker = endMarker
        self.redirectIP = redirectIP
    }

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

        // stale 마커가 있어도 항상 "클린 상태"를 백업한다.
        let cleanContent = try buildCleanContent()
        let backupDirectory = (backupPath as NSString).deletingLastPathComponent

        try FileManager.default.createDirectory(
            atPath: backupDirectory,
            withIntermediateDirectories: true
        )
        try cleanContent.write(toFile: backupPath, atomically: true, encoding: .utf8)
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
            guard !normalized.isEmpty, isValidDomain(normalized) else {
                logger.warning("유효하지 않은 도메인 건너뜀: \(domain, privacy: .public)")
                continue
            }

            // 도메인 자체와 www 서브도메인 모두 차단
            // IPv4 + IPv6 loopback + IPv6 link-local 3중 차단 (macOS IPv6 우선 해석 대응)
            // TAB 구분자 사용 (macOS hosts 파일 기본 형식)
            let targets = normalized.hasPrefix("www.") ? [normalized] : [normalized, "www.\(normalized)"]
            for target in targets {
                blockEntries.append("\(redirectIP)\t\(target)")
                blockEntries.append("\(Constants.Blocking.redirectIPv6)\t\(target)")
                blockEntries.append("\(Constants.Blocking.redirectIPv6LinkLocal)\t\(target)")
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

    // MARK: - 키워드 차단 (v1.3)

    /// 키워드 패턴으로부터 차단 도메인 후보 생성
    /// hosts 파일 제한으로 주요 TLD 조합만 생성
    nonisolated func expandKeywordPattern(_ keyword: String) -> [String] {
        let tlds = ["com", "net", "org", "io", "co"]
        let normalized = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        return tlds.map { "\(normalized).\($0)" }
    }

    // MARK: - 화이트리스트 모드 (v1.3)

    /// top-sites.json에서 허용 도메인을 제외한 차단 콘텐츠 생성
    func buildAllowlistContent(allowedDomains: [String], bundle: Bundle = .main) throws -> String {
        let topSites = Self.loadTopSites(bundle: bundle)
        guard !topSites.isEmpty else {
            logger.warning("top-sites.json 로드 실패 또는 비어있음")
            throw FocusYouError.hostsFileWriteFailed
        }

        let allowedSet = Set(allowedDomains.map { $0.lowercased() })
        let domainsToBlock = topSites.filter { !allowedSet.contains($0.lowercased()) }

        return try buildBlockedContent(domains: domainsToBlock)
    }

    /// 번들에서 top-sites.json 로드
    private static func loadTopSites(bundle: Bundle) -> [String] {
        let candidateURLs = [
            bundle.url(forResource: "top-sites", withExtension: "json"),
            bundle.url(forResource: "top-sites", withExtension: "json", subdirectory: "Presets"),
            bundle.url(forResource: "top-sites", withExtension: "json", subdirectory: "Resources/Presets"),
        ]

        guard let url = candidateURLs.compactMap({ $0 }).first,
              let data = try? Data(contentsOf: url),
              let sites = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return sites
    }

    // MARK: - Private

    /// 도메인 형식 검증 (알파벳, 숫자, 하이픈, 점만 허용 + 점 최소 1개)
    private func isValidDomain(_ domain: String) -> Bool {
        let pattern = #"^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)+$"#
        return domain.range(of: pattern, options: .regularExpression) != nil
    }

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
#endif
