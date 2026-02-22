import XCTest
@testable import Focus_You

final class PrivilegedHelperTests: XCTestCase {
    func testShellEscapeBacktick() async {
        let helper = PrivilegedHelper.shared
        let result = await helper.shellEscapeForDoubleQuotes("echo `whoami`")
        XCTAssertEqual(result, "echo \\`whoami\\`")
    }

    func testShellEscapeDollarSign() async {
        let helper = PrivilegedHelper.shared
        let result = await helper.shellEscapeForDoubleQuotes("$HOME/$USER")
        XCTAssertEqual(result, "\\$HOME/\\$USER")
    }

    func testShellEscapeMixedSpecialCharacters() async {
        let helper = PrivilegedHelper.shared
        let result = await helper.shellEscapeForDoubleQuotes("`$`")
        XCTAssertEqual(result, "\\`\\$\\`")
    }

    func testShellEscapePlainStringUnchanged() async {
        let helper = PrivilegedHelper.shared
        let result = await helper.shellEscapeForDoubleQuotes("hello world")
        XCTAssertEqual(result, "hello world")
    }

    func testShellEscapeEmptyStringUnchanged() async {
        let helper = PrivilegedHelper.shared
        let result = await helper.shellEscapeForDoubleQuotes("")
        XCTAssertEqual(result, "")
    }
}
