//
//  SyncService.swift
//  MCP Contxt
//
//  DEPRECATED: Sync service removed in simplified architecture
//  Servers are now written directly to ~/.claude.json via ClaudeConfigService
//  This stub exists to prevent build errors from any remaining references
//

import Foundation
import Combine
import SwiftUI

@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var pendingChanges: Bool = false

    private init() {}

    func setAutoSync(enabled: Bool) {
        // No-op in simplified architecture
    }

    func sync() async throws {
        // No-op - servers are written directly to ~/.claude.json
    }

    func syncServer(_ server: MCPServer) async throws {
        // No-op - servers are written directly to ~/.claude.json
    }

    func removeAndSync(_ server: MCPServer) async throws {
        // Use registry directly
        try await ServerRegistry.shared.remove(server)
    }
}
