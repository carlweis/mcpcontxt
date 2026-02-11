//
//  MCPStatusCheckerTests.swift
//  MCPContxtTests
//
//  Tests for MCPStatusChecker parsing logic
//

import XCTest
@testable import MCPContxt

final class MCPStatusCheckerTests: XCTestCase {

    var checker: MCPStatusChecker!

    override func setUp() {
        checker = MCPStatusChecker.shared
        // Reset statuses before each test
        checker.statuses = [:]
    }

    // MARK: - parseStatusLine

    func testParseConnectedLine() {
        let line = "slack: https://mcp.slack.com/mcp (HTTP) - ✓ Connected"
        let result = checker.parseStatusLine(line)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "slack")
        XCTAssertEqual(result?.status, .connected)
    }

    func testParseNeedsAuthLine() {
        let line = "notion: https://mcp.notion.so/mcp (HTTP) - ! Needs authentication"
        let result = checker.parseStatusLine(line)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "notion")
        XCTAssertEqual(result?.status, .needsAuth)
    }

    func testParseFailedLine() {
        let line = "github: https://api.github.com/mcp (HTTP) - ✗ Failed to connect"
        let result = checker.parseStatusLine(line)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "github")
        XCTAssertEqual(result?.status, .failed)
    }

    func testParseUnknownStatusLine() {
        let line = "myserver: http://localhost:3000 (HTTP) - something else"
        let result = checker.parseStatusLine(line)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "myserver")
        XCTAssertEqual(result?.status, .unknown)
    }

    func testParseLineWithoutColon() {
        let line = "no colon here"
        let result = checker.parseStatusLine(line)

        XCTAssertNil(result)
    }

    func testParseLineWithExtraWhitespace() {
        let line = "  slack  : https://mcp.slack.com/mcp (HTTP) - ✓ Connected  "
        let result = checker.parseStatusLine(line)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "slack")
        XCTAssertEqual(result?.status, .connected)
    }

    func testParseEmptyLine() {
        let line = ""
        let result = checker.parseStatusLine(line)

        XCTAssertNil(result)
    }

    // MARK: - parseOutput

    func testParseOutputWithMultipleServers() {
        let output = """
        Checking MCP servers...

        slack: https://mcp.slack.com/mcp (HTTP) - ✓ Connected
        notion: https://mcp.notion.so/mcp (HTTP) - ! Needs authentication
        github: https://api.github.com/mcp (HTTP) - ✗ Failed to connect
        """

        checker.parseOutput(output)

        XCTAssertEqual(checker.statuses.count, 3)
        XCTAssertEqual(checker.statuses["slack"], .connected)
        XCTAssertEqual(checker.statuses["notion"], .needsAuth)
        XCTAssertEqual(checker.statuses["github"], .failed)
    }

    func testParseOutputWithEmptyString() {
        checker.parseOutput("")

        XCTAssertEqual(checker.statuses.count, 0)
    }

    func testParseOutputSkipsHeaderLines() {
        let output = """
        Checking MCP servers...

        slack: https://mcp.slack.com/mcp (HTTP) - ✓ Connected
        """

        checker.parseOutput(output)

        XCTAssertEqual(checker.statuses.count, 1)
        XCTAssertEqual(checker.statuses["slack"], .connected)
        XCTAssertNil(checker.statuses["Checking MCP servers..."])
    }

    func testParseOutputWithMalformedLines() {
        let output = """
        some garbage
        another line without colon
        slack: https://mcp.slack.com/mcp (HTTP) - ✓ Connected
        """

        checker.parseOutput(output)

        // "some garbage" and "another line without colon" have no colons, so skipped
        // Only slack should parse
        XCTAssertEqual(checker.statuses["slack"], .connected)
    }

    func testParseConnectedWithTextOnly() {
        let line = "myserver: http://example.com (HTTP) - connected"
        let result = checker.parseStatusLine(line)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status, .connected)
    }

    func testParseFailedWithTextOnly() {
        let line = "myserver: http://example.com (HTTP) - failed"
        let result = checker.parseStatusLine(line)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status, .failed)
    }
}
