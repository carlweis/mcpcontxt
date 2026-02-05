//
//  HealthMonitor.swift
//  MCPContxt
//
//  DEPRECATED: Health monitoring removed in simplified architecture
//  This stub exists to prevent build errors from any remaining references
//

import Foundation
import Combine

@MainActor
class HealthMonitor: ObservableObject {
    static let shared = HealthMonitor()

    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var lastCheckAt: Date?

    private init() {}

    func startMonitoring(interval: TimeInterval = 30) {
        // No-op in simplified architecture
    }

    func stopMonitoring() {
        // No-op in simplified architecture
    }

    func setCheckInterval(_ interval: TimeInterval) {
        // No-op in simplified architecture
    }
}
