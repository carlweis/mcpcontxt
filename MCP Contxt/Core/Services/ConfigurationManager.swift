//
//  ConfigurationManager.swift
//  MCP Contxt
//
//  Coordinates all configuration operations between sources
//

import Foundation
import Combine

@MainActor
class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()

    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncError: Error?
    @Published private(set) var syncStatuses: [SyncTarget: SyncStatus] = [:]

    private let registry: ServerRegistry
    private let claudeDesktop: ClaudeDesktopConfig
    private let claudeCode: ClaudeCodeConfig
    private let enterpriseReader: EnterpriseConfigReader

    private init(
        registry: ServerRegistry = .shared,
        claudeDesktop: ClaudeDesktopConfig = .shared,
        claudeCode: ClaudeCodeConfig = .shared,
        enterpriseReader: EnterpriseConfigReader = .shared
    ) {
        self.registry = registry
        self.claudeDesktop = claudeDesktop
        self.claudeCode = claudeCode
        self.enterpriseReader = enterpriseReader

        initializeSyncStatuses()
    }

    private func initializeSyncStatuses() {
        for target in SyncTarget.allCases {
            let error: String? = {
                if !target.isAvailable {
                    return "Not installed"
                }
                if !target.configFileExists {
                    return "Config not created"
                }
                return nil
            }()

            syncStatuses[target] = SyncStatus(
                target: target,
                isSynced: target.configFileExists,
                lastSyncedAt: nil,
                error: error
            )
        }
    }

    // MARK: - Discovery & Import

    func discoverExistingServers() async throws -> DiscoveryResult {
        var result = DiscoveryResult()

        // Discover Claude Desktop servers
        if claudeDesktop.isAvailable {
            do {
                let servers = try claudeDesktop.importServers()
                result.claudeDesktopServers = servers
            } catch {
                result.claudeDesktopError = error
            }
        }

        // Discover Claude Code servers
        do {
            let servers = try claudeCode.importServers()
            result.claudeCodeServers = servers
        } catch {
            result.claudeCodeError = error
        }

        // Discover Enterprise servers
        do {
            let servers = try enterpriseReader.importEnterpriseServers()
            result.enterpriseServers = servers
        } catch {
            result.enterpriseError = error
        }

        return result
    }

    func importDiscoveredServers(_ servers: [MCPServer], replacing: Bool = false) async throws {
        try await registry.importServers(servers, replacing: replacing)
    }

    // MARK: - Sync Operations

    func syncAll() async throws {
        isSyncing = true
        defer { isSyncing = false }

        lastSyncError = nil

        // Sync to Claude Desktop
        if claudeDesktop.isAvailable {
            do {
                try await syncToClaudeDesktop()
                syncStatuses[.claudeDesktop] = SyncStatus(
                    target: .claudeDesktop,
                    isSynced: true,
                    lastSyncedAt: Date(),
                    error: nil
                )
            } catch {
                syncStatuses[.claudeDesktop] = SyncStatus(
                    target: .claudeDesktop,
                    isSynced: false,
                    lastSyncedAt: nil,
                    error: error.localizedDescription
                )
                lastSyncError = error
            }
        }

        // Sync to Claude Code
        do {
            try await syncToClaudeCode()
            syncStatuses[.claudeCodeUser] = SyncStatus(
                target: .claudeCodeUser,
                isSynced: true,
                lastSyncedAt: Date(),
                error: nil
            )
        } catch {
            syncStatuses[.claudeCodeUser] = SyncStatus(
                target: .claudeCodeUser,
                isSynced: false,
                lastSyncedAt: nil,
                error: error.localizedDescription
            )
            lastSyncError = error
        }

        // Update sync timestamps for all servers
        for server in registry.servers where server.isEnabled {
            try? await registry.markSynced(for: server.id)
        }
    }

    func syncToClaudeDesktop() async throws {
        let serversToSync = registry.servers.filter {
            $0.syncTargets.contains(.claudeDesktop) && $0.isEnabled
        }

        try claudeDesktop.exportServers(serversToSync)
    }

    func syncToClaudeCode() async throws {
        let serversToSync = registry.servers.filter {
            $0.syncTargets.contains(.claudeCodeUser) && $0.isEnabled
        }

        try claudeCode.exportServers(serversToSync)
    }

    func syncServer(_ server: MCPServer) async throws {
        if server.syncTargets.contains(.claudeDesktop) && claudeDesktop.isAvailable {
            try claudeDesktop.exportServers([server])
        }

        if server.syncTargets.contains(.claudeCodeUser) {
            try claudeCode.exportServers([server])
        }

        try await registry.markSynced(for: server.id)
    }

    func removeServerFromTargets(_ server: MCPServer) async throws {
        if server.syncTargets.contains(.claudeDesktop) && claudeDesktop.isAvailable {
            try claudeDesktop.removeServer(named: server.name)
        }

        if server.syncTargets.contains(.claudeCodeUser) {
            try claudeCode.removeServer(named: server.name)
        }
    }

    // MARK: - Status

    var isClaudeDesktopAvailable: Bool {
        claudeDesktop.isAvailable
    }

    var isClaudeCodeAvailable: Bool {
        claudeCode.isAvailable
    }

    var hasEnterpriseConfig: Bool {
        enterpriseReader.hasEnterpriseConfig
    }
}

// MARK: - Discovery Result

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

    // Merge servers, preferring the most recently seen
    var mergedServers: [MCPServer] {
        var serversByName: [String: MCPServer] = [:]

        // Add in order of priority (later overwrites earlier)
        for server in claudeCodeServers {
            serversByName[server.name] = server
        }
        for server in claudeDesktopServers {
            serversByName[server.name] = server
        }
        for server in enterpriseServers {
            serversByName[server.name] = server
        }

        return Array(serversByName.values)
    }
}
