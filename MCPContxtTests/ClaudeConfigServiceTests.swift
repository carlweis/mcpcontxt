//
//  ClaudeConfigServiceTests.swift
//  MCPContxtTests
//
//  Tests for ClaudeConfigService read/write operations
//

import XCTest
@testable import MCPContxt

final class ClaudeConfigServiceTests: XCTestCase {

    var tempDir: URL!
    var configURL: URL!
    var service: ClaudeConfigService!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MCPContxtTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        configURL = tempDir.appendingPathComponent(".claude.json")
        service = ClaudeConfigService(configURL: configURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Read

    func testReadServersFromValidConfig() throws {
        let json: [String: Any] = [
            "mcpServers": [
                "slack": ["type": "http", "url": "https://mcp.slack.com/mcp"],
                "filesystem": ["command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem"]]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        try data.write(to: configURL)

        let servers = service.readServers()

        XCTAssertEqual(servers.count, 2)
        XCTAssertEqual(servers["slack"]?.url, "https://mcp.slack.com/mcp")
        XCTAssertEqual(servers["slack"]?.type, "http")
        XCTAssertEqual(servers["filesystem"]?.command, "npx")
        XCTAssertEqual(servers["filesystem"]?.args, ["-y", "@modelcontextprotocol/server-filesystem"])
    }

    func testReadServersWhenFileDoesNotExist() {
        XCTAssertFalse(service.configExists)
        let servers = service.readServers()
        XCTAssertTrue(servers.isEmpty)
    }

    func testReadServersWithEmptyMcpServers() throws {
        let json: [String: Any] = ["mcpServers": [:] as [String: Any]]
        let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        try data.write(to: configURL)

        let servers = service.readServers()
        XCTAssertTrue(servers.isEmpty)
    }

    func testReadServersWithNoMcpServersKey() throws {
        let json: [String: Any] = ["someOtherKey": "value"]
        let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        try data.write(to: configURL)

        let servers = service.readServers()
        XCTAssertTrue(servers.isEmpty)
    }

    // MARK: - Add Server

    func testAddHTTPServer() throws {
        let config = MCPServerConfig(type: "http", url: "https://mcp.example.com/mcp")
        try service.addServer(name: "example", config: config)

        let servers = service.readServers()
        XCTAssertEqual(servers.count, 1)
        XCTAssertEqual(servers["example"]?.url, "https://mcp.example.com/mcp")
        XCTAssertEqual(servers["example"]?.type, "http")
    }

    func testAddStdioServer() throws {
        let config = MCPServerConfig(
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-github"],
            env: ["GITHUB_TOKEN": "abc123"]
        )
        try service.addServer(name: "github", config: config)

        let servers = service.readServers()
        XCTAssertEqual(servers.count, 1)
        XCTAssertEqual(servers["github"]?.command, "npx")
        XCTAssertEqual(servers["github"]?.args, ["-y", "@modelcontextprotocol/server-github"])
        XCTAssertEqual(servers["github"]?.env?["GITHUB_TOKEN"], "abc123")
    }

    // MARK: - Remove Server

    func testRemoveServer() throws {
        let config1 = MCPServerConfig(type: "http", url: "https://mcp.slack.com/mcp")
        let config2 = MCPServerConfig(type: "http", url: "https://mcp.notion.so/mcp")
        try service.addServer(name: "slack", config: config1)
        try service.addServer(name: "notion", config: config2)

        try service.removeServer(name: "slack")

        let servers = service.readServers()
        XCTAssertEqual(servers.count, 1)
        XCTAssertNil(servers["slack"])
        XCTAssertNotNil(servers["notion"])
    }

    func testRemoveNonexistentServer() throws {
        let config = MCPServerConfig(type: "http", url: "https://mcp.slack.com/mcp")
        try service.addServer(name: "slack", config: config)

        try service.removeServer(name: "nonexistent")

        let servers = service.readServers()
        XCTAssertEqual(servers.count, 1)
        XCTAssertNotNil(servers["slack"])
    }

    // MARK: - Round-trip

    func testWriteThenReadBack() throws {
        let servers: [String: MCPServerConfig] = [
            "slack": MCPServerConfig(type: "http", url: "https://mcp.slack.com/mcp", headers: ["Authorization": "Bearer token"]),
            "filesystem": MCPServerConfig(command: "npx", args: ["-y", "server-fs"], env: ["HOME": "/Users/test"])
        ]
        try service.writeServers(servers)

        let readBack = service.readServers()
        XCTAssertEqual(readBack.count, 2)
        XCTAssertEqual(readBack["slack"]?.url, "https://mcp.slack.com/mcp")
        XCTAssertEqual(readBack["slack"]?.headers?["Authorization"], "Bearer token")
        XCTAssertEqual(readBack["filesystem"]?.command, "npx")
        XCTAssertEqual(readBack["filesystem"]?.env?["HOME"], "/Users/test")
    }

    func testPreservesOtherJsonFields() throws {
        // Write initial JSON with extra fields
        let json: [String: Any] = [
            "someOtherField": "preserved",
            "mcpServers": ["slack": ["type": "http", "url": "https://mcp.slack.com/mcp"]]
        ]
        let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        try data.write(to: configURL)

        // Add a new server (should preserve someOtherField)
        let config = MCPServerConfig(type: "http", url: "https://mcp.notion.so/mcp")
        try service.addServer(name: "notion", config: config)

        // Verify other fields preserved
        let rawData = try Data(contentsOf: configURL)
        let rawJson = try JSONSerialization.jsonObject(with: rawData) as! [String: Any]
        XCTAssertEqual(rawJson["someOtherField"] as? String, "preserved")
    }

    // MARK: - MCPServerConfig properties

    func testMCPServerConfigIsHTTP() {
        let config = MCPServerConfig(type: "http", url: "https://example.com")
        XCTAssertTrue(config.isHTTP)
        XCTAssertFalse(config.isSSE)
        XCTAssertFalse(config.isStdio)
    }

    func testMCPServerConfigIsSSE() {
        let config = MCPServerConfig(type: "sse", url: "https://example.com")
        XCTAssertTrue(config.isSSE)
        XCTAssertFalse(config.isStdio)
    }

    func testMCPServerConfigIsStdio() {
        let config = MCPServerConfig(command: "npx", args: ["-y", "server"])
        XCTAssertTrue(config.isStdio)
        XCTAssertFalse(config.isHTTP)
        XCTAssertFalse(config.isSSE)
    }

    func testMCPServerConfigInferredHTTPFromURL() {
        let config = MCPServerConfig(url: "https://example.com")
        XCTAssertTrue(config.isHTTP)
    }
}
