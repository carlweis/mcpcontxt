//
//  ClaudeDesktopConfig.swift
//  MCPControl
//
//  DEPRECATED: Claude Desktop uses Connectors, not MCP config files
//  This stub exists to prevent build errors from any remaining references
//

import Foundation

class ClaudeDesktopConfig {
    static let shared = ClaudeDesktopConfig()

    private init() {}

    var isAvailable: Bool {
        false // Claude Desktop uses Connectors, not config files
    }

    func importServers() throws -> [MCPServer] {
        return []
    }

    func exportServers(_ servers: [MCPServer]) throws {
        // No-op - Claude Desktop uses Connectors
    }

    func removeServer(named: String) throws {
        // No-op - Claude Desktop uses Connectors
    }
}

// MARK: - Config File Models (kept for compatibility)

struct ClaudeDesktopConfigFile: Codable {
    var mcpServers: [String: ClaudeDesktopServerConfig]?

    init(mcpServers: [String: ClaudeDesktopServerConfig]? = nil) {
        self.mcpServers = mcpServers
    }
}

struct ClaudeDesktopServerConfig: Codable {
    var type: String?
    var url: String?
    var headers: [String: String]?
    var command: String?
    var args: [String]?
    var env: [String: String]?
}

// MARK: - MCPServer Extension

extension MCPServer {
    func toClaudeDesktopConfig() -> ClaudeDesktopServerConfig {
        return ClaudeDesktopServerConfig(
            type: type.rawValue,
            url: configuration.url,
            headers: configuration.headers,
            command: configuration.command,
            args: configuration.args,
            env: configuration.env
        )
    }
}

// MARK: - Helper Types

struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Unsupported type"))
        }
    }
}
