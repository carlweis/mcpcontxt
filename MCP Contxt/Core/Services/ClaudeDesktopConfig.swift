//
//  ClaudeDesktopConfig.swift
//  MCP Contxt
//
//  Read/write Claude Desktop configuration file
//

import Foundation

class ClaudeDesktopConfig {
    static let shared = ClaudeDesktopConfig()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var configURL: URL {
        SyncTarget.claudeDesktop.configPath
    }

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
    }

    func read() throws -> ClaudeDesktopConfigFile {
        guard fileManager.fileExists(atPath: configURL.path) else {
            return ClaudeDesktopConfigFile()
        }

        let data = try Data(contentsOf: configURL)
        return try decoder.decode(ClaudeDesktopConfigFile.self, from: data)
    }

    func write(_ config: ClaudeDesktopConfigFile) throws {
        // Ensure directory exists
        let directory = configURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }

    func readServers() throws -> [String: ClaudeDesktopServerConfig] {
        let config = try read()
        return config.mcpServers ?? [:]
    }

    func writeServers(_ servers: [String: ClaudeDesktopServerConfig]) throws {
        var config = try read()
        config.mcpServers = servers
        try write(config)
    }

    func importServers() throws -> [MCPServer] {
        let serverConfigs = try readServers()

        return serverConfigs.map { name, config in
            let serverType: MCPServerType
            let configuration: MCPServerConfiguration

            if let type = config.type, type == "http" {
                serverType = .http
                configuration = .http(
                    url: config.url ?? "",
                    headers: config.headers
                )
            } else if config.url != nil {
                serverType = .sse
                configuration = .http(
                    url: config.url ?? "",
                    headers: config.headers
                )
            } else {
                serverType = .stdio
                configuration = .stdio(
                    command: config.command ?? "",
                    args: config.args,
                    env: config.env
                )
            }

            return MCPServer(
                name: name,
                type: serverType,
                configuration: configuration,
                source: .claudeDesktop
            )
        }
    }

    func exportServers(_ servers: [MCPServer]) throws {
        var existingServers = try readServers()

        for server in servers where server.syncTargets.contains(.claudeDesktop) && server.isEnabled {
            let config = server.toClaudeDesktopConfig()
            existingServers[server.name] = config
        }

        try writeServers(existingServers)
    }

    func removeServer(named name: String) throws {
        var servers = try readServers()
        servers.removeValue(forKey: name)
        try writeServers(servers)
    }

    var isAvailable: Bool {
        SyncTarget.claudeDesktop.isAvailable
    }
}

// MARK: - Config File Models

struct ClaudeDesktopConfigFile: Codable {
    var mcpServers: [String: ClaudeDesktopServerConfig]?

    // Preserve other fields that may exist in the config
    var additionalFields: [String: AnyCodable]?

    init(mcpServers: [String: ClaudeDesktopServerConfig]? = nil) {
        self.mcpServers = mcpServers
    }

    enum CodingKeys: String, CodingKey {
        case mcpServers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mcpServers = try container.decodeIfPresent([String: ClaudeDesktopServerConfig].self, forKey: .mcpServers)

        // Decode any additional fields
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var additional = [String: AnyCodable]()
        for key in dynamicContainer.allKeys {
            if key.stringValue != "mcpServers" {
                additional[key.stringValue] = try dynamicContainer.decode(AnyCodable.self, forKey: key)
            }
        }
        additionalFields = additional.isEmpty ? nil : additional
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(mcpServers, forKey: .mcpServers)

        // Encode additional fields
        if let additional = additionalFields {
            var dynamicContainer = encoder.container(keyedBy: DynamicCodingKeys.self)
            for (key, value) in additional {
                try dynamicContainer.encode(value, forKey: DynamicCodingKeys(stringValue: key)!)
            }
        }
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
        switch type {
        case .http:
            return ClaudeDesktopServerConfig(
                type: "http",
                url: configuration.url,
                headers: configuration.headers
            )
        case .sse:
            return ClaudeDesktopServerConfig(
                url: configuration.url,
                headers: configuration.headers
            )
        case .stdio:
            return ClaudeDesktopServerConfig(
                command: configuration.command,
                args: configuration.args,
                env: configuration.env
            )
        }
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
