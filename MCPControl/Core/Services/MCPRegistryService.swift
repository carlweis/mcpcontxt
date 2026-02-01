//
//  MCPRegistryService.swift
//  MCPControl
//
//  Fetches available MCP servers from the Anthropic registry
//

import Foundation

class MCPRegistryService {
    static let shared = MCPRegistryService()

    private let registryURL = URL(string: "https://api.anthropic.com/mcp-registry/v0/servers")!

    private init() {}

    struct RegistryResponse: Codable {
        let servers: [RegistryServerEntry]
        let metadata: RegistryMetadata?
    }

    struct RegistryMetadata: Codable {
        let nextCursor: String?
    }

    struct RegistryServerEntry: Codable {
        let server: ServerInfo
        let _meta: ServerMeta?

        enum CodingKeys: String, CodingKey {
            case server
            case _meta
        }
    }

    struct ServerInfo: Codable {
        let name: String?
        let title: String?
        let description: String?
        let remotes: [RemoteInfo]?
        let packages: [PackageInfo]?
    }

    struct RemoteInfo: Codable {
        let type: String?
        let url: String?
    }

    struct PackageInfo: Codable {
        let registryType: String?
        let identifier: String?
        let environmentVariables: [EnvVarInfo]?
    }

    struct EnvVarInfo: Codable {
        let name: String?
        let description: String?
    }

    struct ServerMeta: Codable {
        let registry: RegistryMeta?

        enum CodingKeys: String, CodingKey {
            case registry = "com.anthropic.api/mcp-registry"
        }
    }

    struct RegistryMeta: Codable {
        let displayName: String?
        let oneLiner: String?
        let documentation: String?
        let url: String?
        let worksWith: [String]?
    }

    // Parsed server for display
    struct DiscoveredServer: Identifiable, Hashable {
        let id: String
        let name: String
        let description: String?
        let documentationURL: String?
        let httpURL: String?
        let sseURL: String?
        let stdioCommand: String?
        let envVars: [String]
        let worksWithClaudeCode: Bool
        let worksWithClaudeDesktop: Bool

        var hasRemoteURL: Bool {
            httpURL != nil || sseURL != nil
        }

        var preferredURL: String? {
            httpURL ?? sseURL
        }

        var transportType: String {
            if httpURL != nil { return "HTTP" }
            if sseURL != nil { return "SSE" }
            if stdioCommand != nil { return "Stdio" }
            return "Unknown"
        }
    }

    func fetchServers() async throws -> [DiscoveredServer] {
        var allServers: [DiscoveredServer] = []
        var cursor: String? = nil

        repeat {
            var url = registryURL
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            var queryItems = [URLQueryItem(name: "version", value: "latest"), URLQueryItem(name: "limit", value: "100")]
            if let cursor = cursor {
                queryItems.append(URLQueryItem(name: "cursor", value: cursor))
            }
            components.queryItems = queryItems
            url = components.url!

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw MCPRegistryError.fetchFailed
            }

            let decoded = try JSONDecoder().decode(RegistryResponse.self, from: data)

            let servers = decoded.servers.compactMap { entry -> DiscoveredServer? in
                let meta = entry._meta?.registry
                let server = entry.server

                let name = meta?.displayName ?? server.title ?? server.name ?? "Unknown"
                let description = meta?.oneLiner ?? server.description

                // Find remote URLs
                var httpURL: String? = nil
                var sseURL: String? = nil

                if let remotes = server.remotes {
                    for remote in remotes {
                        if remote.type == "streamable-http" || remote.type == "http" {
                            httpURL = remote.url
                        } else if remote.type == "sse" {
                            sseURL = remote.url
                        }
                    }
                }

                // Fallback to meta URL
                if httpURL == nil && sseURL == nil {
                    if let metaURL = meta?.url {
                        httpURL = metaURL
                    }
                }

                // Find stdio command
                var stdioCommand: String? = nil
                var envVars: [String] = []

                if let packages = server.packages {
                    for pkg in packages {
                        if pkg.registryType == "npm", let identifier = pkg.identifier {
                            stdioCommand = "npx -y \(identifier)"
                            if let vars = pkg.environmentVariables {
                                envVars = vars.compactMap { $0.name }
                            }
                            break
                        }
                    }
                }

                // Skip if no connection method
                guard httpURL != nil || sseURL != nil || stdioCommand != nil else {
                    return nil
                }

                // Skip templated URLs (require user-specific values)
                if let url = httpURL, url.contains("{") {
                    return nil
                }
                if let url = sseURL, url.contains("{") {
                    return nil
                }

                let worksWith = meta?.worksWith ?? []

                return DiscoveredServer(
                    id: server.name ?? name,
                    name: name,
                    description: description,
                    documentationURL: meta?.documentation,
                    httpURL: httpURL,
                    sseURL: sseURL,
                    stdioCommand: stdioCommand,
                    envVars: envVars,
                    worksWithClaudeCode: worksWith.contains("claude-code"),
                    worksWithClaudeDesktop: worksWith.contains("claude-desktop")
                )
            }

            allServers.append(contentsOf: servers)
            cursor = decoded.metadata?.nextCursor

        } while cursor != nil

        // Sort by name
        return allServers.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}

enum MCPRegistryError: Error, LocalizedError {
    case fetchFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Failed to fetch MCP registry"
        case .invalidResponse:
            return "Invalid response from MCP registry"
        }
    }
}
