//
//  ServerRegistry.swift
//  MCPControl
//
//  Manages MCP servers from ~/.claude.json
//  Source of truth for the UI - reads/writes directly to Claude config
//

import Foundation
import Combine
import SwiftUI

@MainActor
class ServerRegistry: ObservableObject {
    static let shared = ServerRegistry()

    @Published private(set) var servers: [MCPServer] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: Error?

    private init() {}

    // MARK: - Load from ~/.claude.json

    func load() async {
        await loadFromClaudeConfig()
    }

    func loadFromClaudeConfig() async {
        print("[ServerRegistry] Starting load from ~/.claude.json")
        isLoading = true
        defer { isLoading = false }

        let configServers = ClaudeConfigService.shared.readServers()
        print("[ServerRegistry] Got \(configServers.count) servers from ClaudeConfigService")

        servers = configServers.map { (name, config) in
            MCPServer(
                name: name,
                type: serverType(from: config),
                configuration: MCPServerConfiguration(
                    url: config.url,
                    headers: config.headers,
                    command: config.command,
                    args: config.args,
                    env: config.env
                ),
                isEnabled: true,
                syncTargets: [.claudeCodeUser],
                source: .claudeCode
            )
        }.sorted { $0.name < $1.name }

        print("[ServerRegistry] Loaded \(servers.count) servers: \(servers.map { $0.name }.joined(separator: ", "))")
        lastError = nil
    }

    private func serverType(from config: MCPServerConfig) -> MCPServerType {
        if config.isSSE { return .sse }
        if config.isHTTP { return .http }
        if config.isStdio { return .stdio }
        return .http
    }

    // MARK: - Add/Remove Servers

    func add(_ server: MCPServer) async throws {
        let config = MCPServerConfig(
            type: server.type.rawValue,
            url: server.configuration.url,
            headers: server.configuration.headers,
            command: server.configuration.command,
            args: server.configuration.args,
            env: server.configuration.env
        )

        try ClaudeConfigService.shared.addServer(name: server.name, config: config)
        await loadFromClaudeConfig()
    }

    func remove(_ server: MCPServer) async throws {
        try ClaudeConfigService.shared.removeServer(name: server.name)
        await loadFromClaudeConfig()
    }

    func remove(at offsets: IndexSet) async throws {
        let serversToRemove = offsets.map { servers[$0] }
        for server in serversToRemove {
            try ClaudeConfigService.shared.removeServer(name: server.name)
        }
        await loadFromClaudeConfig()
    }

    // MARK: - Queries

    func server(withName name: String) -> MCPServer? {
        servers.first { $0.name == name }
    }

    func server(withID id: UUID) -> MCPServer? {
        servers.first { $0.id == id }
    }

    var enabledServers: [MCPServer] {
        servers.filter { $0.isEnabled }
    }

    var overallHealthStatus: HealthStatus {
        // Simple status - just check if we have servers
        if servers.isEmpty { return .unknown }
        return .healthy
    }

    // MARK: - Refresh

    func refresh() async {
        await loadFromClaudeConfig()
    }
}
