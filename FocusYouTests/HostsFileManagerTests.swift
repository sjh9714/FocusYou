import Foundation
import XCTest
@testable import Focus_You

final class HostsFileManagerTests: XCTestCase {
    private var tempDirectoryURL: URL!
    private var hostsURL: URL!
    private var backupURL: URL!

    override func setUpWithError() throws {
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("focusyou-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)

        hostsURL = tempDirectoryURL.appendingPathComponent("hosts")
        backupURL = tempDirectoryURL.appendingPathComponent("hosts.backup")
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
    }

    func testBuildBlockedContentReplacesExistingMarkerSection() async throws {
        let existing = """
        127.0.0.1 localhost
        # === Focus You BEGIN ===
        0.0.0.0 old.com
        # === Focus You END ===
        """
        try existing.write(to: hostsURL, atomically: true, encoding: .utf8)

        let manager = HostsFileManager(
            hostsPath: hostsURL.path,
            backupPath: backupURL.path
        )

        let blocked = try await manager.buildBlockedContent(
            domains: ["https://www.Example.com/path", "github.com"]
        )

        XCTAssertEqual(blocked.components(separatedBy: Constants.Blocking.beginMarker).count - 1, 1)
        XCTAssertEqual(blocked.components(separatedBy: Constants.Blocking.endMarker).count - 1, 1)
        XCTAssertFalse(blocked.contains("old.com"))
        XCTAssertTrue(blocked.contains("0.0.0.0\texample.com"))
        XCTAssertTrue(blocked.contains("0.0.0.0\twww.example.com"))
        XCTAssertTrue(blocked.contains("0.0.0.0\tgithub.com"))
        XCTAssertTrue(blocked.contains("0.0.0.0\twww.github.com"))
    }

    func testBackupHostsFileStoresCleanContentWithoutMarkers() async throws {
        let contentWithMarkers = """
        127.0.0.1 localhost
        # === Focus You BEGIN ===
        0.0.0.0 example.com
        # === Focus You END ===
        """
        try contentWithMarkers.write(to: hostsURL, atomically: true, encoding: .utf8)

        let manager = HostsFileManager(
            hostsPath: hostsURL.path,
            backupPath: backupURL.path
        )

        try await manager.backupHostsFile()

        let backupContent = try String(contentsOf: backupURL, encoding: .utf8)
        XCTAssertFalse(backupContent.contains(Constants.Blocking.beginMarker))
        XCTAssertFalse(backupContent.contains(Constants.Blocking.endMarker))
        XCTAssertTrue(backupContent.contains("127.0.0.1 localhost"))
    }
}
