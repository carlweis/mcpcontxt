//
//  SyncTarget.swift
//  MCPContxt
//
//  Defines the targets where MCP configurations can be synced
//

import Foundation

enum SyncTarget: String, Codable, CaseIterable, Hashable {
    case claudeDesktop      // ~/Library/Application Support/Claude/claude_desktop_config.json
    case claudeCodeUser     // ~/.claude.json

    var displayName: String {
        switch self {
        case .claudeDesktop: return "Claude Desktop"
        case .claudeCodeUser: return "Claude Code CLI"
        }
    }

    var configPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser

        switch self {
        case .claudeDesktop:
            return home
                .appendingPathComponent("Library")
                .appendingPathComponent("Application Support")
                .appendingPathComponent("Claude")
                .appendingPathComponent("claude_desktop_config.json")
        case .claudeCodeUser:
            return home.appendingPathComponent(".claude.json")
        }
    }

    var configDirectory: URL {
        configPath.deletingLastPathComponent()
    }

    var description: String {
        switch self {
        case .claudeDesktop:
            return "~/Library/Application Support/Claude/claude_desktop_config.json"
        case .claudeCodeUser:
            return "~/.claude.json"
        }
    }

    var isAvailable: Bool {
        let fileManager = FileManager.default

        switch self {
        case .claudeDesktop:
            // Check if Claude Desktop directory exists (meaning Claude Desktop is installed)
            return fileManager.fileExists(atPath: configDirectory.path)
        case .claudeCodeUser:
            // Claude Code user config is always available (home directory)
            return true
        }
    }

    var configFileExists: Bool {
        FileManager.default.fileExists(atPath: configPath.path)
    }

    var statusDescription: String {
        if !isAvailable {
            switch self {
            case .claudeDesktop:
                return "Claude Desktop not installed"
            case .claudeCodeUser:
                return "Not available"
            }
        }

        if !configFileExists {
            return "Config not created yet"
        }

        return "Ready"
    }
}

struct SyncStatus: Equatable {
    let target: SyncTarget
    let isSynced: Bool
    let lastSyncedAt: Date?
    let error: String?

    var statusText: String {
        if let error = error {
            return error
        }
        if isSynced {
            if let lastSynced = lastSyncedAt {
                return "Synced \(lastSynced.relativeTimeString)"
            }
            return "Synced"
        }
        return "Not synced"
    }
}

extension Date {
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
