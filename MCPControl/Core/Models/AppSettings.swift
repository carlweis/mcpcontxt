//
//  AppSettings.swift
//  MCPControl
//
//  Application settings and preferences
//

import Foundation

struct AppSettings: Codable {
    var syncTargets: Set<SyncTarget>
    var autoSyncOnChanges: Bool
    var launchAtLogin: Bool
    var showInDock: Bool
    var healthCheckInterval: TimeInterval
    var showNotificationOnFailure: Bool
    var showNotificationOnAuthExpiry: Bool
    var debugLoggingEnabled: Bool

    init(
        syncTargets: Set<SyncTarget> = [.claudeDesktop, .claudeCodeUser],
        autoSyncOnChanges: Bool = true,
        launchAtLogin: Bool = false,
        showInDock: Bool = true,
        healthCheckInterval: TimeInterval = 30,
        showNotificationOnFailure: Bool = true,
        showNotificationOnAuthExpiry: Bool = true,
        debugLoggingEnabled: Bool = false
    ) {
        self.syncTargets = syncTargets
        self.autoSyncOnChanges = autoSyncOnChanges
        self.launchAtLogin = launchAtLogin
        self.showInDock = showInDock
        self.healthCheckInterval = healthCheckInterval
        self.showNotificationOnFailure = showNotificationOnFailure
        self.showNotificationOnAuthExpiry = showNotificationOnAuthExpiry
        self.debugLoggingEnabled = debugLoggingEnabled
    }

    static let `default` = AppSettings()
}

enum HealthCheckInterval: TimeInterval, CaseIterable, Identifiable {
    case fifteenSeconds = 15
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300
    case tenMinutes = 600

    var id: TimeInterval { rawValue }

    var displayName: String {
        switch self {
        case .fifteenSeconds: return "Every 15 seconds"
        case .thirtySeconds: return "Every 30 seconds"
        case .oneMinute: return "Every minute"
        case .fiveMinutes: return "Every 5 minutes"
        case .tenMinutes: return "Every 10 minutes"
        }
    }
}
