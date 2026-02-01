//
//  EnterpriseConfigReader.swift
//  MCP Contxt
//
//  DEPRECATED: Enterprise config removed in simplified architecture
//  This stub exists to prevent build errors from any remaining references
//

import Foundation

class EnterpriseConfigReader {
    static let shared = EnterpriseConfigReader()

    private init() {}

    func readSystemConfig() throws -> EnterpriseMCPConfig? {
        return nil
    }

    func readUserConfig() throws -> EnterpriseMCPConfig? {
        return nil
    }

    func importEnterpriseServers() throws -> [MCPServer] {
        return []
    }

    var hasEnterpriseConfig: Bool {
        false
    }

    var systemConfigExists: Bool {
        false
    }

    var userConfigExists: Bool {
        false
    }
}

// MARK: - Enterprise Config Models (kept for compatibility)

struct EnterpriseMCPConfig: Codable {
    var mcpServers: [String: EnterpriseMCPServerConfig]?
}

struct EnterpriseMCPServerConfig: Codable {
    var type: String?
    var url: String?
    var headers: [String: String]?
    var command: String?
    var args: [String]?
    var env: [String: String]?
}
