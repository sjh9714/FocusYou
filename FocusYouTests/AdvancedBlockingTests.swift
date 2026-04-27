import XCTest
@testable import Focus_You

final class AdvancedBlockingTests: XCTestCase {

    // MARK: - 키워드 확장

    func testExpandKeywordPatternProducesTLDVariants() {
        let manager = HostsFileManager(
            hostsPath: "/tmp/focusyou-test-hosts-\(UUID().uuidString)",
            backupPath: "/tmp/focusyou-test-backup-\(UUID().uuidString)"
        )

        let results = manager.expandKeywordPattern("youtube")
        XCTAssertTrue(results.contains("youtube.com"))
        XCTAssertTrue(results.contains("youtube.net"))
        XCTAssertTrue(results.contains("youtube.org"))
        XCTAssertTrue(results.contains("youtube.io"))
        XCTAssertTrue(results.contains("youtube.co"))
        XCTAssertEqual(results.count, 5)
    }

    func testExpandKeywordPatternNormalizesInput() {
        let manager = HostsFileManager(
            hostsPath: "/tmp/focusyou-test-hosts-\(UUID().uuidString)",
            backupPath: "/tmp/focusyou-test-backup-\(UUID().uuidString)"
        )

        let results = manager.expandKeywordPattern("  YouTube  ")
        XCTAssertTrue(results.contains("youtube.com"))
    }

    func testExpandKeywordPatternReturnsEmptyForBlank() {
        let manager = HostsFileManager(
            hostsPath: "/tmp/focusyou-test-hosts-\(UUID().uuidString)",
            backupPath: "/tmp/focusyou-test-backup-\(UUID().uuidString)"
        )

        let results = manager.expandKeywordPattern("   ")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - 화이트리스트 콘텐츠 생성

    func testBuildAllowlistContentExcludesAllowedDomains() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("focusyou-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let hostsPath = tempDir.appendingPathComponent("hosts").path
        let backupPath = tempDir.appendingPathComponent("hosts.backup").path
        try "127.0.0.1 localhost".write(toFile: hostsPath, atomically: true, encoding: .utf8)

        let manager = HostsFileManager(hostsPath: hostsPath, backupPath: backupPath)

        let content = try await manager.buildAllowlistContent(allowedDomains: ["google.com", "github.com"])

        // 허용된 도메인은 차단 목록에 없어야 함
        XCTAssertFalse(content.contains("0.0.0.0\tgoogle.com"))
        XCTAssertFalse(content.contains("0.0.0.0\tgithub.com"))

        // 마커가 포함되어야 함
        XCTAssertTrue(content.contains(Constants.Blocking.beginMarker))
        XCTAssertTrue(content.contains(Constants.Blocking.endMarker))

        try? FileManager.default.removeItem(at: tempDir)
    }
}
