//
//  EnterpriseConfigReader.swift
//  MCP Contxt
//
//  Read enterprise managed MCP configurations (read-only)
//

import Foundation

class EnterpriseConfigReader {
    static let shared = EnterpriseConfigReader()

    private let fileManager = FileManager.default
    private let decoder: JSONDecoder

    // System-wide enterprise config
    private var systemConfigURL: URL {
        URL(fileURLWithPath: "/Library/Application Support/Anthropic/managed-mcp.json")
    }

    // User-level enterprise config
    private var userConfigURL: URL {
        let home = fileManager.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("Anthropic")
            .appendingPathComponent("managed-mcp.json")
    }

    private init() {
        decoder = JSONDecoder()
    }

    func readSystemConfig() throws -> EnterpriseMCPConfig? {
        guard fileManager.fileExists(atPath: systemConfigURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: systemConfigURL)
        return try decoder.decode(EnterpriseMCPConfig.self, from: data)
    }

    func readUserConfig() throws -> EnterpriseMCPConfig? {
        guard fileManager.fileExists(atPath: userConfigURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: userConfigURL)
        return try decoder.decode(EnterpriseMCPConfig.self, from: data)
    }

    func importEnterpriseServers() throws -> [MCPServer] {
        var servers: [MCPServer] = []

        // Read system-wide config
        if let systemConfig = try readSystemConfig() {
            servers.append(contentsOf: convertToMCPServers(systemConfig))
        }

        // Read user-level config (these take precedence for same names)
        if let userConfig = try readUserConfig() {
            let userServers = convertToMCPServers(userConfig)
            for server in userServers {
                if let existingIndex = servers.firstIndex(where: { $0.name == server.name }) {
                    servers[existingIndex] = server
                } else {
                    servers.append(server)
                }
            }
        }

        return servers
    }

    private func convertToMCPServers(_ config: EnterpriseMCPConfig) -> [MCPServer] {
        guard let mcpServers = config.mcpServers else { return [] }

        return mcpServers.compactMap { name, serverConfig -> MCPServer? in
            let serverType: MCPServerType
            let configuration: MCPServerConfiguration

            if serverConfig.type == "http" {
                serverType = .http
                configuration = .http(
                    url: serverConfig.url ?? "",
                    headers: serverConfig.headers
                )
            } else if serverConfig.url != nil {
                serverType = .sse
                configuration = .http(
                    url: serverConfig.url ?? "",
                    headers: serverConfig.headers
                )
            } else if serverConfig.command != nil {
                serverType = .stdio
                configuration = .stdio(
                    command: serverConfig.command ?? "",
                    args: serverConfig.args,
                    env: serverConfig.env
                )
            } else {
                return nil
            }

            return MCPServer(
                name: name,
                type: serverType,
                configuration: configuration,
                isEnabled: true,
                syncTargets: [], // Enterprise servers are managed externally
                source: .enterprise
            )
        }
    }

    var hasEnterpriseConfig: Bool {
        fileManager.fileExists(atPath: systemConfigURL.path) ||
        fileManager.fileExists(atPath: userConfigURL.path)
    }

    var systemConfigExists: Bool {
        fileManager.fileExists(atPath: systemConfigURL.path)
    }

    var userConfigExists: Bool {
        fileManager.fileExists(atPath: userConfigURL.path)
    }
}

// MARK: - Enterprise Config Models

struct EnterpriseMCPConfig: Codable {
    var mcpServers: [String: EnterpriseMCPServerConfig]?
}

struct EnterpriseMCPServerConfig: Codable {
    var type: String?
    var url: String?
    var headers: [String: String]?
    var command: String?
    var args: [String]?
    var env: [String: String]?
}
