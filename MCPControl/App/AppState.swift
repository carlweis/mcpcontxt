//
//  AppState.swift
//  MCP Contxt
//
//  Global application state
//

import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    // Core services
    let registry = ServerRegistry.shared
    let configManager = ConfigurationManager.shared
    let syncService = SyncService.shared
    let healthMonitor = HealthMonitor.shared

    // UI State
    @Published var showingSettings = false
    @Published var showingAddServer = false
    @Published var showingImport = false
    @Published var selectedServer: MCPServer?

    // Status
    @Published var isInitialized = false
    @Published var hasExternalChanges = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        // Watch for external config changes
        ConfigurationFileWatcher.shared.$hasExternalChanges
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasExternalChanges)
    }

    func initialize() async {
        await registry.load()
        isInitialized = true
    }

    func acknowledgeExternalChanges() {
        ConfigurationFileWatcher.shared.clearChanges()
    }

    func refreshFromExternalChanges() async {
        await registry.loadFromClaudeConfig()
        acknowledgeExternalChanges()
    }
}

// MARK: - Environment Key

struct AppStateKey: EnvironmentKey {
    static let defaultValue = AppState.shared
}

extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}
