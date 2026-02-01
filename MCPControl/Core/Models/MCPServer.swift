//
//  MCPServer.swift
//  MCPControl
//
//  Core server definition - our source of truth for MCP server configurations
//

import Foundation

struct MCPServer: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var type: MCPServerType
    var configuration: MCPServerConfiguration
    var isEnabled: Bool
    var syncTargets: Set<SyncTarget>
    var metadata: MCPServerMetadata
    var source: ServerSource

    init(
        id: UUID = UUID(),
        name: String,
        type: MCPServerType,
        configuration: MCPServerConfiguration,
        isEnabled: Bool = true,
        syncTargets: Set<SyncTarget> = [.claudeDesktop, .claudeCodeUser],
        metadata: MCPServerMetadata = MCPServerMetadata(),
        source: ServerSource = .mcpContxt
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.configuration = configuration
        self.isEnabled = isEnabled
        self.syncTargets = syncTargets
        self.metadata = metadata
        self.source = source
    }
}

enum MCPServerType: String, Codable, CaseIterable {
    case http       // Remote HTTP server (recommended)
    case sse        // Server-Sent Events (deprecated but still used)
    case stdio      // Local process

    var displayName: String {
        switch self {
        case .http: return "HTTP"
        case .sse: return "SSE"
        case .stdio: return "stdio"
        }
    }

    var description: String {
        switch self {
        case .http: return "Remote HTTP Server (Recommended)"
        case .sse: return "Server-Sent Events"
        case .stdio: return "Local Process"
        }
    }
}

struct MCPServerConfiguration: Codable, Hashable {
    // For HTTP/SSE servers
    var url: String?
    var headers: [String: String]?

    // For stdio servers
    var command: String?
    var args: [String]?
    var env: [String: String]?

    init(
        url: String? = nil,
        headers: [String: String]? = nil,
        command: String? = nil,
        args: [String]? = nil,
        env: [String: String]? = nil
    ) {
        self.url = url
        self.headers = headers
        self.command = command
        self.args = args
        self.env = env
    }

    static func http(url: String, headers: [String: String]? = nil) -> MCPServerConfiguration {
        MCPServerConfiguration(url: url, headers: headers)
    }

    static func stdio(command: String, args: [String]? = nil, env: [String: String]? = nil) -> MCPServerConfiguration {
        MCPServerConfiguration(command: command, args: args, env: env)
    }
}

struct MCPServerMetadata: Codable, Hashable {
    var createdAt: Date
    var lastModifiedAt: Date
    var lastSyncedAt: Date?
    var lastHealthCheckAt: Date?
    var healthStatus: HealthStatus
    var healthMessage: String?
    var requiresAuth: Bool
    var authExpiresAt: Date?

    init(
        createdAt: Date = Date(),
        lastModifiedAt: Date = Date(),
        lastSyncedAt: Date? = nil,
        lastHealthCheckAt: Date? = nil,
        healthStatus: HealthStatus = .unknown,
        healthMessage: String? = nil,
        requiresAuth: Bool = false,
        authExpiresAt: Date? = nil
    ) {
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
        self.lastSyncedAt = lastSyncedAt
        self.lastHealthCheckAt = lastHealthCheckAt
        self.healthStatus = healthStatus
        self.healthMessage = healthMessage
        self.requiresAuth = requiresAuth
        self.authExpiresAt = authExpiresAt
    }
}

enum ServerSource: String, Codable, CaseIterable {
    case mcpContxt           // Created in our app
    case claudeDesktop       // Imported from Claude Desktop
    case claudeCode          // Imported from Claude Code
    case enterprise          // From managed-mcp.json (read-only)

    var displayName: String {
        switch self {
        case .mcpContxt: return "MCP Control"
        case .claudeDesktop: return "Claude Desktop"
        case .claudeCode: return "Claude Code"
        case .enterprise: return "Enterprise"
        }
    }

    var isEditable: Bool {
        self != .enterprise
    }
}
