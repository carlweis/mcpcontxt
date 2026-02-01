//
//  SyncService.swift
//  MCP Contxt
//
//  Handles automatic and manual sync operations
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

    private let configManager: ConfigurationManager
    private let registry: ServerRegistry
    private var cancellables = Set<AnyCancellable>()
    private var autoSyncEnabled: Bool = true

    private init(
        configManager: ConfigurationManager = .shared,
        registry: ServerRegistry = .shared
    ) {
        self.configManager = configManager
        self.registry = registry
        setupObservers()
    }

    private func setupObservers() {
        // Watch for server changes
        registry.$servers
            .dropFirst()
            .sink { [weak self] _ in
                self?.pendingChanges = true
                if self?.autoSyncEnabled == true {
                    Task {
                        try? await self?.syncIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
    }

    func setAutoSync(enabled: Bool) {
        autoSyncEnabled = enabled
    }

    func syncIfNeeded() async throws {
        guard pendingChanges, !isSyncing else { return }

        try await sync()
    }

    func sync() async throws {
        guard !isSyncing else { return }

        isSyncing = true
        defer {
            isSyncing = false
            pendingChanges = false
            lastSyncAt = Date()
        }

        try await configManager.syncAll()
    }

    func syncServer(_ server: MCPServer) async throws {
        try await configManager.syncServer(server)
    }

    func removeAndSync(_ server: MCPServer) async throws {
        try await configManager.removeServerFromTargets(server)
        try await registry.remove(server)
    }
}
