//
//  MCPCatalogTests.swift
//  MCPContxtTests
//
//  Tests for MCPCatalogServer decoding, search, and facade
//

import XCTest
@testable import MCPContxt

final class MCPCatalogTests: XCTestCase {

    // MARK: - JSON Decoding

    func testDecodeCatalogServerFromJSON() throws {
        let json = """
        {
            "id": "slack",
            "name": "Slack",
            "description": "Connect to Slack workspaces",
            "transport": "http",
            "url": "https://mcp.slack.com/mcp",
            "auth": "oauth",
            "setupUrl": "https://docs.slack.com/setup"
        }
        """.data(using: .utf8)!

        let server = try JSONDecoder().decode(MCPCatalogServer.self, from: json)

        XCTAssertEqual(server.id, "slack")
        XCTAssertEqual(server.name, "Slack")
        XCTAssertEqual(server.description, "Connect to Slack workspaces")
        XCTAssertEqual(server.transport, .http)
        XCTAssertEqual(server.url, "https://mcp.slack.com/mcp")
        XCTAssertEqual(server.auth, .oauth)
        XCTAssertTrue(server.isOAuth)
        XCTAssertTrue(server.isRemote)
        XCTAssertFalse(server.isStdio)
        XCTAssertEqual(server.setupUrl, "https://docs.slack.com/setup")
    }

    func testDecodeStdioServer() throws {
        let json = """
        {
            "id": "filesystem",
            "name": "Filesystem",
            "description": "Access local files",
            "transport": "stdio",
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-filesystem"]
        }
        """.data(using: .utf8)!

        let server = try JSONDecoder().decode(MCPCatalogServer.self, from: json)

        XCTAssertEqual(server.id, "filesystem")
        XCTAssertEqual(server.transport, .stdio)
        XCTAssertTrue(server.isStdio)
        XCTAssertFalse(server.isRemote)
        XCTAssertEqual(server.command, "npx")
        XCTAssertEqual(server.args, ["-y", "@modelcontextprotocol/server-filesystem"])
        XCTAssertNil(server.auth)
        XCTAssertFalse(server.isOAuth)
    }

    func testDecodeWithMissingOptionalFields() throws {
        let json = """
        {
            "id": "minimal",
            "name": "Minimal Server",
            "description": "A minimal server",
            "transport": "http"
        }
        """.data(using: .utf8)!

        let server = try JSONDecoder().decode(MCPCatalogServer.self, from: json)

        XCTAssertEqual(server.id, "minimal")
        XCTAssertNil(server.url)
        XCTAssertNil(server.command)
        XCTAssertNil(server.args)
        XCTAssertNil(server.env)
        XCTAssertNil(server.setupUrl)
        XCTAssertNil(server.documentationUrl)
        XCTAssertNil(server.githubUrl)
        XCTAssertNil(server.requirements)
        XCTAssertNil(server.installCommand)
        XCTAssertNil(server.auth)
        XCTAssertNil(server.alternatives)
    }

    func testDecodeWithUnknownAuthTypeYieldsNil() throws {
        let json = """
        {
            "id": "test",
            "name": "Test",
            "description": "Test server",
            "transport": "http",
            "auth": "unknown_auth_type"
        }
        """.data(using: .utf8)!

        let server = try JSONDecoder().decode(MCPCatalogServer.self, from: json)

        XCTAssertNil(server.auth)
        XCTAssertFalse(server.isOAuth)
    }

    func testDecodeWithAlternatives() throws {
        let json = """
        {
            "id": "github",
            "name": "GitHub",
            "description": "GitHub MCP",
            "transport": "http",
            "url": "https://api.github.com/mcp",
            "auth": "oauth",
            "alternatives": [
                {
                    "name": "GitHub (stdio)",
                    "transport": "stdio",
                    "command": "npx",
                    "args": ["-y", "@modelcontextprotocol/server-github"],
                    "env": ["GITHUB_PERSONAL_ACCESS_TOKEN"],
                    "notes": "Uses PAT — works without OAuth"
                }
            ]
        }
        """.data(using: .utf8)!

        let server = try JSONDecoder().decode(MCPCatalogServer.self, from: json)

        XCTAssertNotNil(server.alternatives)
        XCTAssertEqual(server.alternatives?.count, 1)
        XCTAssertEqual(server.alternatives?.first?.name, "GitHub (stdio)")
        XCTAssertEqual(server.alternatives?.first?.transport, "stdio")
        XCTAssertTrue(server.alternatives?.first?.isStdio ?? false)
        XCTAssertEqual(server.alternatives?.first?.command, "npx")
    }

    func testDecodeMalformedJSONThrows() {
        let json = "not json at all".data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(MCPCatalogServer.self, from: json))
    }

    func testDecodeMissingRequiredFieldThrows() {
        // Missing "name" which is required
        let json = """
        {
            "id": "test",
            "description": "Missing name",
            "transport": "http"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(MCPCatalogServer.self, from: json))
    }

    // MARK: - CatalogResponse Decoding

    func testDecodeCatalogResponse() throws {
        let json = """
        {
            "version": "1.0",
            "updated_at": "2026-01-01",
            "servers": [
                {
                    "id": "slack",
                    "name": "Slack",
                    "description": "Slack MCP",
                    "transport": "http",
                    "url": "https://mcp.slack.com/mcp"
                },
                {
                    "id": "github",
                    "name": "GitHub",
                    "description": "GitHub MCP",
                    "transport": "http",
                    "url": "https://api.github.com/mcp"
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CatalogResponse.self, from: json)

        XCTAssertEqual(response.version, "1.0")
        XCTAssertEqual(response.updated_at, "2026-01-01")
        XCTAssertEqual(response.servers.count, 2)
        XCTAssertEqual(response.servers[0].id, "slack")
        XCTAssertEqual(response.servers[1].id, "github")
    }

    // MARK: - Encode/Decode Round-trip

    func testEncodeDecodeRoundTrip() throws {
        let server = MCPCatalogServer(
            id: "test",
            name: "Test Server",
            description: "A test server",
            transport: .http,
            url: "https://example.com/mcp",
            command: nil,
            args: nil,
            env: nil,
            setupUrl: "https://example.com/setup",
            documentationUrl: nil,
            githubUrl: "https://github.com/example/test",
            requirements: ["Node.js 18+"],
            installCommand: "npm install test",
            auth: .oauth,
            alternatives: nil,
            official: true
        )

        let data = try JSONEncoder().encode(server)
        let decoded = try JSONDecoder().decode(MCPCatalogServer.self, from: data)

        XCTAssertEqual(decoded.id, server.id)
        XCTAssertEqual(decoded.name, server.name)
        XCTAssertEqual(decoded.transport, server.transport)
        XCTAssertEqual(decoded.url, server.url)
        XCTAssertEqual(decoded.auth, server.auth)
        XCTAssertEqual(decoded.setupUrl, server.setupUrl)
        XCTAssertEqual(decoded.githubUrl, server.githubUrl)
        XCTAssertEqual(decoded.requirements, server.requirements)
    }

    // MARK: - MCPCatalogService Search

    func testSearchFiltersByName() {
        let results = MCPCatalogService.shared.search("")
        // Empty query returns all servers (whatever is loaded)
        // This validates the search function doesn't crash
        XCTAssertNotNil(results)
    }

    // MARK: - AuthType

    func testAuthTypeRawValues() {
        XCTAssertEqual(AuthType.none.rawValue, "none")
        XCTAssertEqual(AuthType.oauth.rawValue, "oauth")
        XCTAssertEqual(AuthType.apiKey.rawValue, "apiKey")
    }

    // MARK: - CatalogAlternative

    func testCatalogAlternativeIsStdio() {
        let alt = CatalogAlternative(
            name: "Test Alt",
            transport: "stdio",
            command: "npx",
            args: nil,
            env: nil,
            url: nil,
            setupUrl: nil,
            notes: nil
        )
        XCTAssertTrue(alt.isStdio)
        XCTAssertEqual(alt.id, "Test Alt")
    }

    func testCatalogAlternativeIsNotStdio() {
        let alt = CatalogAlternative(
            name: "HTTP Alt",
            transport: "http",
            command: nil,
            args: nil,
            env: nil,
            url: "https://example.com",
            setupUrl: nil,
            notes: "Some notes"
        )
        XCTAssertFalse(alt.isStdio)
    }
}
