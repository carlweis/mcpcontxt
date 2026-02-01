//
//  ClaudeCodeConfig.swift
//  MCPControl
//
//  DEPRECATED: Use ClaudeConfigService instead for direct ~/.claude.json operations
//  This stub exists to prevent build errors from any remaining references
//

import Foundation

class ClaudeCodeConfig {
    static let shared = ClaudeCodeConfig()

    private init() {}

    var isAvailable: Bool {
        true
    }

    func importServers() throws -> [MCPServer] {
        // Redirect to ClaudeConfigService
        let configServers = ClaudeConfigService.shared.readServers()
        return configServers.map { (name, config) in
            let serverType: MCPServerType = config.isSSE ? .sse : (config.isStdio ? .stdio : .http)
            return MCPServer(
                name: name,
                type: serverType,
                configuration: MCPServerConfiguration(
                    url: config.url,
                    headers: config.headers,
                    command: config.command,
                    args: config.args,
                    env: config.env
                ),
                source: .claudeCode
            )
        }
    }

    func exportServers(_ servers: [MCPServer]) throws {
        // No-op - use ClaudeConfigService directly
    }

    func removeServer(named name: String) throws {
        // Redirect to ClaudeConfigService
        try ClaudeConfigService.shared.removeServer(name: name)
    }
}

// MARK: - Config File Models (kept for compatibility)

struct ClaudeCodeConfigFile: Codable {
    var mcpServers: [String: ClaudeCodeServerConfig]?

    init(mcpServers: [String: ClaudeCodeServerConfig]? = nil) {
        self.mcpServers = mcpServers
    }
}

struct ClaudeCodeServerConfig: Codable {
    var type: String?
    var url: String?
    var headers: [String: String]?
    var command: String?
    var args: [String]?
    var env: [String: String]?
}

// MARK: - MCPServer Extension

extension MCPServer {
    func toClaudeCodeConfig() -> ClaudeCodeServerConfig {
        return ClaudeCodeServerConfig(
            type: type.rawValue,
            url: configuration.url,
            headers: configuration.headers,
            command: configuration.command,
            args: configuration.args,
            env: configuration.env
        )
    }
}
