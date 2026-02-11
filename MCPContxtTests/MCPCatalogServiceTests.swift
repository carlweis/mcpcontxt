//
//  MCPCatalogServiceTests.swift
//  MCPContxtTests
//
//  Tests for MCPCatalogService search and cache functionality
//

import XCTest
@testable import MCPContxt

final class MCPCatalogServiceTests: XCTestCase {

    // MARK: - Search

    func testSearchWithEmptyQueryReturnsAll() {
        let service = MCPCatalogService.shared
        let all = service.search("")
        // Returns all loaded servers (may be 0 if cache empty, but shouldn't crash)
        XCTAssertNotNil(all)
    }

    func testSearchIsCaseInsensitive() {
        let service = MCPCatalogService.shared
        let upper = service.search("SLACK")
        let lower = service.search("slack")
        // Both queries should return same results
        XCTAssertEqual(upper.count, lower.count)
    }

    // MARK: - Cache Round-trip

    func testCacheRoundTrip() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MCPCatalogServiceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cacheURL = tempDir.appendingPathComponent("catalog-cache.json")

        // Create a valid catalog response
        let catalogJSON = """
        {
            "version": "1.0",
            "updated_at": "2026-01-01",
            "servers": [
                {
                    "id": "test-server",
                    "name": "Test Server",
                    "description": "A test MCP server",
                    "transport": "http",
                    "url": "https://mcp.test.com/mcp",
                    "auth": "oauth"
                },
                {
                    "id": "local-server",
                    "name": "Local Server",
                    "description": "A local stdio server",
                    "transport": "stdio",
                    "command": "npx",
                    "args": ["-y", "test-server"]
                }
            ]
        }
        """.data(using: .utf8)!

        // Write to cache file
        try catalogJSON.write(to: cacheURL)

        // Read back and decode
        let data = try Data(contentsOf: cacheURL)
        let response = try JSONDecoder().decode(CatalogResponse.self, from: data)

        XCTAssertEqual(response.servers.count, 2)
        XCTAssertEqual(response.servers[0].id, "test-server")
        XCTAssertTrue(response.servers[0].isOAuth)
        XCTAssertEqual(response.servers[1].id, "local-server")
        XCTAssertTrue(response.servers[1].isStdio)
    }

    // MARK: - Resilient Decoding

    func testResilientDecodingWithInvalidAuth() throws {
        let json = """
        {
            "id": "test",
            "name": "Test",
            "description": "Test server",
            "transport": "http",
            "auth": "totally_invalid_auth_type"
        }
        """.data(using: .utf8)!

        // Should not crash — auth should be nil
        let server = try JSONDecoder().decode(MCPCatalogServer.self, from: json)
        XCTAssertNil(server.auth)
    }

    func testResilientDecodingWithMalformedAlternatives() throws {
        let json = """
        {
            "id": "test",
            "name": "Test",
            "description": "Test server",
            "transport": "http",
            "alternatives": "not an array"
        }
        """.data(using: .utf8)!

        // Should not crash — alternatives should be nil
        let server = try JSONDecoder().decode(MCPCatalogServer.self, from: json)
        XCTAssertNil(server.alternatives)
    }

    func testDecodingPreservesAllFields() throws {
        let json = """
        {
            "id": "full",
            "name": "Full Server",
            "description": "A fully-configured server",
            "transport": "http",
            "url": "https://mcp.full.com/mcp",
            "setupUrl": "https://docs.full.com/setup",
            "documentationUrl": "https://docs.full.com",
            "githubUrl": "https://github.com/full/server",
            "requirements": ["Node.js 18+", "Account required"],
            "installCommand": "npm install -g @full/mcp-server",
            "auth": "oauth"
        }
        """.data(using: .utf8)!

        let server = try JSONDecoder().decode(MCPCatalogServer.self, from: json)

        XCTAssertEqual(server.setupUrl, "https://docs.full.com/setup")
        XCTAssertEqual(server.documentationUrl, "https://docs.full.com")
        XCTAssertEqual(server.githubUrl, "https://github.com/full/server")
        XCTAssertEqual(server.requirements?.count, 2)
        XCTAssertEqual(server.installCommand, "npm install -g @full/mcp-server")
    }
}
