//
//  ClaudeConfigService.swift
//  MCPContxt
//
//  Simple read/write for ~/.claude.json MCP servers
//  Uses JSONSerialization to handle complex file without failing
//

import Foundation

class ClaudeConfigService {
    static let shared = ClaudeConfigService()

    private let configURL: URL

    private init() {
        // Get the REAL home directory, not the sandboxed one
        // FileManager.homeDirectoryForCurrentUser returns sandboxed path
        let realHomeDirectory: URL
        if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir {
            realHomeDirectory = URL(fileURLWithPath: String(cString: home))
        } else {
            // Fallback to environment variable
            realHomeDirectory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory())
        }
        configURL = realHomeDirectory.appendingPathComponent(".claude.json")
    }

    var configExists: Bool {
        FileManager.default.fileExists(atPath: configURL.path)
    }

    var configPath: String {
        configURL.path
    }

    // MARK: - Read Servers

    func readServers() -> [String: MCPServerConfig] {
        print("[ClaudeConfigService] Reading servers from \(configURL.path)")

        guard configExists else {
            print("[ClaudeConfigService] Config file does not exist at \(configURL.path)")
            return [:]
        }

        do {
            let data = try Data(contentsOf: configURL)
            print("[ClaudeConfigService] Read \(data.count) bytes from file")

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[ClaudeConfigService] Failed to parse JSON as dictionary")
                return [:]
            }

            print("[ClaudeConfigService] Parsed JSON with \(json.keys.count) top-level keys")

            // Try to get mcpServers - handle both dict of dicts and other formats
            guard let mcpServersRaw = json["mcpServers"] else {
                print("[ClaudeConfigService] No mcpServers key found. Top-level keys: \(Array(json.keys).sorted().joined(separator: ", "))")
                return [:]
            }

            print("[ClaudeConfigService] mcpServers type: \(type(of: mcpServersRaw))")

            guard let mcpServers = mcpServersRaw as? [String: Any] else {
                print("[ClaudeConfigService] mcpServers is not a dictionary")
                return [:]
            }

            print("[ClaudeConfigService] Found \(mcpServers.count) server entries: \(mcpServers.keys.joined(separator: ", "))")

            var result: [String: MCPServerConfig] = [:]
            for (name, configRaw) in mcpServers {
                guard let config = configRaw as? [String: Any] else {
                    print("[ClaudeConfigService] Server '\(name)' config is not a dictionary, skipping")
                    continue
                }

                result[name] = MCPServerConfig(
                    type: config["type"] as? String,
                    url: config["url"] as? String,
                    headers: config["headers"] as? [String: String],
                    command: config["command"] as? String,
                    args: config["args"] as? [String],
                    env: config["env"] as? [String: String]
                )
                print("[ClaudeConfigService] Loaded server: \(name) -> \(config["url"] as? String ?? "no url")")
            }

            print("[ClaudeConfigService] Successfully loaded \(result.count) servers")
            return result

        } catch {
            print("[ClaudeConfigService] Error reading config: \(error)")
            return [:]
        }
    }

    // MARK: - Write Servers

    func addServer(name: String, config: MCPServerConfig) throws {
        var servers = readServers()
        servers[name] = config
        try writeServers(servers)
    }

    func removeServer(name: String) throws {
        print("[ClaudeConfigService] Removing server: \(name)")
        var servers = readServers()
        let removed = servers.removeValue(forKey: name)
        print("[ClaudeConfigService] Server was present: \(removed != nil), remaining: \(servers.count)")
        try writeServers(servers)
        print("[ClaudeConfigService] Server removed and config saved")
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
