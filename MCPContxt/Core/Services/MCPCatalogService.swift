//
//  MCPCatalogService.swift
//  MCPContxt
//
//  Fetches and caches MCP server catalog from remote JSON
//

import Foundation
import Combine

class MCPCatalogService: ObservableObject {
    static let shared = MCPCatalogService()

    @Published private(set) var servers: [MCPCatalogServer] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: Error?
    @Published private(set) var lastUpdated: Date?

    // Remote catalog URL - hosted on mcpcontxt.com
    // Source of truth: https://github.com/carlweis/mcpcontxt-web/blob/main/public/mcp-servers.json
    private let remoteURL = URL(string: "https://mcpcontxt.com/mcp-servers.json")!

    private let cacheURL: URL
    private let fileManager = FileManager.default

    private init() {
        // Setup cache directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cacheDir = appSupport.appendingPathComponent("MCPContxt")
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        cacheURL = cacheDir.appendingPathComponent("catalog-cache.json")

        // Load cached data immediately (remote fetch happens on first view appear)
        loadFromCache()
    }

    // MARK: - Public API

    func refresh() async {
        await MainActor.run {
            isLoading = true
            lastError = nil
        }

        do {
            let servers = try await fetchRemoteCatalog()
            await MainActor.run {
                self.servers = servers
                self.isLoading = false
                self.lastUpdated = Date()
            }
            print("[MCPCatalogService] Fetched \(servers.count) servers from remote")
        } catch {
            print("[MCPCatalogService] Failed to fetch remote catalog: \(error)")
            await MainActor.run {
                self.lastError = error
                self.isLoading = false
            }
            // Keep using cached data if available
        }
    }

    func search(_ query: String) -> [MCPCatalogServer] {
        guard !query.isEmpty else { return servers }
        let q = query.lowercased()
        return servers.filter {
            $0.name.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            $0.id.lowercased().contains(q)
        }
    }

    // MARK: - Private Methods

    private func loadFromCache() {
        guard fileManager.fileExists(atPath: cacheURL.path) else {
            print("[MCPCatalogService] No cache file found")
            return
        }

        do {
            let data = try Data(contentsOf: cacheURL)
            let catalog = try JSONDecoder().decode(CatalogResponse.self, from: data)
            servers = catalog.servers
            print("[MCPCatalogService] Loaded \(servers.count) servers from cache")
        } catch {
            print("[MCPCatalogService] Failed to load cache: \(error)")
        }
    }

    private func fetchRemoteCatalog() async throws -> [MCPCatalogServer] {
        let (data, response) = try await URLSession.shared.data(from: remoteURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CatalogError.fetchFailed
        }

        let catalog = try JSONDecoder().decode(CatalogResponse.self, from: data)

        // Save to cache
        try? data.write(to: cacheURL)
        print("[MCPCatalogService] Saved \(catalog.servers.count) servers to cache")

        return catalog.servers
    }
}

// MARK: - Response Models

private struct CatalogResponse: Codable {
    let version: String
    let updated_at: String
    let servers: [MCPCatalogServer]
}

extension MCPCatalogServer: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, description, url, transport, command, args, env
        case setupUrl, documentationUrl, githubUrl, requirements, installCommand
        case auth, alternatives
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        let transportString = try container.decode(String.self, forKey: .transport)
        transport = TransportType(rawValue: transportString) ?? .http

        // HTTP/SSE fields
        url = try container.decodeIfPresent(String.self, forKey: .url)

        // stdio fields
        command = try container.decodeIfPresent(String.self, forKey: .command)
        args = try container.decodeIfPresent([String].self, forKey: .args)
        env = try container.decodeIfPresent([String].self, forKey: .env)

        // Metadata fields
        setupUrl = try container.decodeIfPresent(String.self, forKey: .setupUrl)
        documentationUrl = try container.decodeIfPresent(String.self, forKey: .documentationUrl)
        githubUrl = try container.decodeIfPresent(String.self, forKey: .githubUrl)
        requirements = try container.decodeIfPresent([String].self, forKey: .requirements)
        installCommand = try container.decodeIfPresent(String.self, forKey: .installCommand)

        // Auth and alternatives (resilient decoding — format mismatch yields nil, not crash)
        if let authString = try container.decodeIfPresent(String.self, forKey: .auth) {
            self.auth = AuthType(rawValue: authString)
        } else {
            self.auth = nil
        }
        self.alternatives = (try? container.decodeIfPresent([CatalogAlternative].self, forKey: .alternatives)) ?? nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(transport.rawValue, forKey: .transport)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(args, forKey: .args)
        try container.encodeIfPresent(env, forKey: .env)
        try container.encodeIfPresent(setupUrl, forKey: .setupUrl)
        try container.encodeIfPresent(documentationUrl, forKey: .documentationUrl)
        try container.encodeIfPresent(githubUrl, forKey: .githubUrl)
        try container.encodeIfPresent(requirements, forKey: .requirements)
        try container.encodeIfPresent(installCommand, forKey: .installCommand)
        try container.encodeIfPresent(auth?.rawValue, forKey: .auth)
        try container.encodeIfPresent(alternatives, forKey: .alternatives)
    }
}

enum CatalogError: LocalizedError {
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Failed to fetch catalog from server"
        }
    }
}
