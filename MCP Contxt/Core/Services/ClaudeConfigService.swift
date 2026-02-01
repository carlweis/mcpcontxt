//
//  ClaudeConfigService.swift
//  MCP Contxt
//
//  Simple read/write for ~/.claude.json MCP servers
//  Uses JSONSerialization to handle complex file without failing
//

import Foundation

class ClaudeConfigService {
    static let shared = ClaudeConfigService()

    private let configURL: URL

    private init() {
        configURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }

    var configExists: Bool {
        FileManager.default.fileExists(atPath: configURL.path)
    }

    var configPath: String {
        configURL.path
    }

    // MARK: - Read Servers

    func readServers() -> [String: MCPServerConfig] {
        guard configExists else {
            print("[ClaudeConfigService] Config file does not exist at \(configURL.path)")
            return [:]
        }

        guard let data = try? Data(contentsOf: configURL) else {
            print("[ClaudeConfigService] Failed to read config file")
            return [:]
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[ClaudeConfigService] Failed to parse JSON")
            return [:]
        }

        guard let mcpServers = json["mcpServers"] as? [String: [String: Any]] else {
            print("[ClaudeConfigService] No mcpServers found in config")
            return [:]
        }

        var result: [String: MCPServerConfig] = [:]
        for (name, config) in mcpServers {
            result[name] = MCPServerConfig(
                type: config["type"] as? String,
                url: config["url"] as? String,
                headers: config["headers"] as? [String: String],
                command: config["command"] as? String,
                args: config["args"] as? [String],
                env: config["env"] as? [String: String]
            )
        }

        print("[ClaudeConfigService] Loaded \(result.count) servers")
        return result
    }

    // MARK: - Write Servers

    func addServer(name: String, config: MCPServerConfig) throws {
        var servers = readServers()
        servers[name] = config
        try writeServers(servers)
    }

    func removeServer(name: String) throws {
        var servers = readServers()
        servers.removeValue(forKey: name)
        try writeServers(servers)
    }

    func writeServers(_ servers: [String: MCPServerConfig]) throws {
        // Read existing file to preserve other fields
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: configURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        // Convert servers to dictionary format
        var mcpDict: [String: [String: Any]] = [:]
        for (name, config) in servers {
            var entry: [String: Any] = [:]
            if let type = config.type { entry["type"] = type }
            if let url = config.url { entry["url"] = url }
            if let headers = config.headers, !headers.isEmpty { entry["headers"] = headers }
            if let command = config.command { entry["command"] = command }
            if let args = config.args, !args.isEmpty { entry["args"] = args }
            if let env = config.env, !env.isEmpty { entry["env"] = env }
            mcpDict[name] = entry
        }

        json["mcpServers"] = mcpDict

        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: configURL, options: .atomic)

        print("[ClaudeConfigService] Wrote \(servers.count) servers to config")
    }
}

// MARK: - Server Config Model

struct MCPServerConfig {
    var type: String?
    var url: String?
    var headers: [String: String]?
    var command: String?
    var args: [String]?
    var env: [String: String]?

    var isHTTP: Bool {
        type == "http" || (type == nil && url != nil)
    }

    var isSSE: Bool {
        type == "sse"
    }

    var isStdio: Bool {
        type == "stdio" || command != nil
    }
}
