//
//  ClaudeCodeConfig.swift
//  MCP Contxt
//
//  Read/write Claude Code CLI configuration file
//

import Foundation

class ClaudeCodeConfig {
    static let shared = ClaudeCodeConfig()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var configURL: URL {
        SyncTarget.claudeCodeUser.configPath
    }

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
    }

    func read() throws -> ClaudeCodeConfigFile {
        guard fileManager.fileExists(atPath: configURL.path) else {
            return ClaudeCodeConfigFile()
        }

        let data = try Data(contentsOf: configURL)
        return try decoder.decode(ClaudeCodeConfigFile.self, from: data)
    }

    func write(_ config: ClaudeCodeConfigFile) throws {
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }

    func readServers() throws -> [String: ClaudeCodeServerConfig] {
        let config = try read()
        return config.mcpServers ?? [:]
    }

    func writeServers(_ servers: [String: ClaudeCodeServerConfig]) throws {
        var config = try read()
        config.mcpServers = servers
        try write(config)
    }

    func importServers() throws -> [MCPServer] {
        let serverConfigs = try readServers()

        return serverConfigs.map { name, config in
            let serverType: MCPServerType
            let configuration: MCPServerConfiguration

            switch config.type {
            case "http":
                serverType = .http
                configuration = .http(
                    url: config.url ?? "",
                    headers: config.headers
                )
            case "sse":
                serverType = .sse
                configuration = .http(
                    url: config.url ?? "",
                    headers: config.headers
                )
            default: // stdio or unspecified
                serverType = .stdio
                configuration = .stdio(
                    command: config.command ?? "",
                    args: config.args,
                    env: config.env
                )
            }

            return MCPServer(
                name: name,
                type: serverType,
                configuration: configuration,
                source: .claudeCode
            )
        }
    }

    func exportServers(_ servers: [MCPServer]) throws {
        var existingServers = try readServers()

        for server in servers where server.syncTargets.contains(.claudeCodeUser) && server.isEnabled {
            let config = server.toClaudeCodeConfig()
            existingServers[server.name] = config
        }

        try writeServers(existingServers)
    }

    func removeServer(named name: String) throws {
        var servers = try readServers()
        servers.removeValue(forKey: name)
        try writeServers(servers)
    }

    var isAvailable: Bool {
        SyncTarget.claudeCodeUser.isAvailable
    }
}

// MARK: - Config File Models

struct ClaudeCodeConfigFile: Codable {
    var mcpServers: [String: ClaudeCodeServerConfig]?

    init(mcpServers: [String: ClaudeCodeServerConfig]? = nil) {
        self.mcpServers = mcpServers
    }

    enum CodingKeys: String, CodingKey {
        case mcpServers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mcpServers = try container.decodeIfPresent([String: ClaudeCodeServerConfig].self, forKey: .mcpServers)
        // We only need mcpServers - ignore all other fields in the file
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(mcpServers, forKey: .mcpServers)
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
        switch type {
        case .http:
            return ClaudeCodeServerConfig(
                type: "http",
                url: configuration.url,
                headers: configuration.headers
            )
        case .sse:
            return ClaudeCodeServerConfig(
                type: "sse",
                url: configuration.url,
                headers: configuration.headers
            )
        case .stdio:
            return ClaudeCodeServerConfig(
                type: "stdio",
                command: configuration.command,
                args: configuration.args,
                env: configuration.env
            )
        }
    }
}
