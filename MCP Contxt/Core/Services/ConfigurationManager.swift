//
//  ConfigurationManager.swift
//  MCP Contxt
//
//  DEPRECATED: Configuration manager removed in simplified architecture
//  Use ClaudeConfigService directly for ~/.claude.json operations
//  This stub exists to prevent build errors from any remaining references
//

import Foundation
import Combine

@MainActor
class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()

    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncError: Error?
    @Published private(set) var syncStatuses: [SyncTarget: SyncStatus] = [:]

    private init() {
        // Initialize with default statuses
        syncStatuses[.claudeCodeUser] = SyncStatus(
            target: .claudeCodeUser,
            isSynced: true,
            lastSyncedAt: nil,
            error: nil
        )
    }

    // MARK: - Status

    var isClaudeDesktopAvailable: Bool {
        false // Claude Desktop uses Connectors, not MCP config files
    }

    var isClaudeCodeAvailable: Bool {
        true
    }

    var hasEnterpriseConfig: Bool {
        false
    }
}

// MARK: - Discovery Result (kept for compatibility)

struct DiscoveryResult {
    var claudeDesktopServers: [MCPServer] = []
    var claudeDesktopError: Error?

    var claudeCodeServers: [MCPServer] = []
    var claudeCodeError: Error?

    var enterpriseServers: [MCPServer] = []
    var enterpriseError: Error?

    var allServers: [MCPServer] {
        claudeDesktopServers + claudeCodeServers + enterpriseServers
    }

    var hasServers: Bool {
        !allServers.isEmpty
    }

    var hasErrors: Bool {
        claudeDesktopError != nil || claudeCodeError != nil || enterpriseError != nil
    }

    var mergedServers: [MCPServer] {
        var serversByName: [String: MCPServer] = [:]
        for server in claudeCodeServers {
            serversByName[server.name] = server
        }
        return Array(serversByName.values)
    }
}
