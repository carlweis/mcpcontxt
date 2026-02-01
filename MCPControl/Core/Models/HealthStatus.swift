//
//  HealthStatus.swift
//  MCPControl
//
//  Health status indicators for MCP servers
//

import SwiftUI

enum HealthStatus: String, Codable, CaseIterable {
    case healthy        // Server responding normally
    case degraded       // Server slow or intermittent
    case unhealthy      // Server failing
    case needsAuth      // OAuth token expired or missing
    case unknown        // Haven't checked yet
    case disabled       // User disabled this server

    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .degraded: return "Degraded"
        case .unhealthy: return "Unhealthy"
        case .needsAuth: return "Needs Authentication"
        case .unknown: return "Unknown"
        case .disabled: return "Disabled"
        }
    }

    var color: Color {
        switch self {
        case .healthy: return .green
        case .degraded: return .yellow
        case .unhealthy: return .red
        case .needsAuth: return .orange
        case .unknown: return .gray
        case .disabled: return .gray
        }
    }

    var systemImage: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .unhealthy: return "xmark.circle.fill"
        case .needsAuth: return "key.fill"
        case .unknown: return "questionmark.circle.fill"
        case .disabled: return "minus.circle.fill"
        }
    }

    var priority: Int {
        switch self {
        case .unhealthy: return 0
        case .needsAuth: return 1
        case .degraded: return 2
        case .unknown: return 3
        case .disabled: return 4
        case .healthy: return 5
        }
    }
}

extension HealthStatus {
    static func overallStatus(from servers: [MCPServer]) -> HealthStatus {
        let enabledServers = servers.filter { $0.isEnabled }

        guard !enabledServers.isEmpty else {
            return .unknown
        }

        let statuses = enabledServers.map { $0.metadata.healthStatus }

        // Return the worst status (lowest priority number)
        return statuses.min(by: { $0.priority < $1.priority }) ?? .unknown
    }
}
