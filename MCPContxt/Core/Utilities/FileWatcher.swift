//
//  FileWatcher.swift
//  MCPContxt
//
//  DEPRECATED: File watching removed in simplified architecture
//  This stub exists to prevent build errors from any remaining references
//

import Foundation
import Combine
import SwiftUI

class FileWatcher {
    func watch(path: URL, onChange: @escaping () -> Void) {
        // No-op in simplified architecture
    }

    func stopWatching(path: URL) {
        // No-op in simplified architecture
    }

    func stopAll() {
        // No-op in simplified architecture
    }
}

// MARK: - Configuration File Watcher

@MainActor
class ConfigurationFileWatcher: ObservableObject {
    static let shared = ConfigurationFileWatcher()

    @Published private(set) var hasExternalChanges: Bool = false
    @Published private(set) var changedTargets: Set<SyncTarget> = []

    private init() {}

    func startWatching(onChange: @escaping () -> Void) {
        // No-op in simplified architecture
    }

    func stopWatching() {
        // No-op in simplified architecture
    }

    func clearChanges() {
        hasExternalChanges = false
        changedTargets.removeAll()
    }
}
