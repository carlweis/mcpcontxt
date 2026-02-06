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

    // Remote catalog URL - hosted on GitHub
    private let remoteURL = URL(string: "https://mcpcontxt.com/mcp-servers.json")!

    private let cacheURL: URL
    private let fileManager = FileManager.default

    private init() {
        // Setup cache directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cacheDir = appSupport.appendingPathComponent("MCPContxt")
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        cacheURL = cacheDir.appendingPathComponent("catalog-cache.json")

        // Load cached data immediately, falling back to bundled resource or local dev file
        if !loadFromCache() {
            if !loadFromBundle() {
                loadFromLocalDev()
            }
        }
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

    @discardableResult
    private func loadFromCache() -> Bool {
        guard fileManager.fileExists(atPath: cacheURL.path) else {
            print("[MCPCatalogService] No cache file found")
            return false
        }

        do {
            let data = try Data(contentsOf: cacheURL)
            let catalog = try JSONDecoder().decode(CatalogResponse.self, from: data)
            servers = catalog.servers
            print("[MCPCatalogService] Loaded \(servers.count) servers from cache")
            return true
        } catch {
            print("[MCPCatalogService] Failed to load cache: \(error)")
            return false
        }
    }

    @discardableResult
    private func loadFromBundle() -> Bool {
        guard let bundleURL = Bundle.main.url(forResource: "mcp-servers", withExtension: "json") else {
            print("[MCPCatalogService] No bundled catalog found")
            return false
        }

        do {
            let data = try Data(contentsOf: bundleURL)
            let catalog = try JSONDecoder().decode(CatalogResponse.self, from: data)
            servers = catalog.servers
            print("[MCPCatalogService] Loaded \(servers.count) servers from bundle")
            return true
        } catch {
            print("[MCPCatalogService] Failed to load bundled catalog: \(error)")
            return false
        }
    }

    /// Development fallback - loads from local project directory
    private func loadFromLocalDev() {
        // Try to find the mcp-servers.json in common development locations
        let possiblePaths = [
            // Xcode derived data paths go up several levels from the build product
            Bundle.main.bundlePath + "/../../../../../../../../mcp-servers.json",
            // Current working directory (for CLI runs)
            FileManager.default.currentDirectoryPath + "/mcp-servers.json",
            // Source root via Xcode environment (if set)
            ProcessInfo.processInfo.environment["SRCROOT"].map { $0 + "/mcp-servers.json" }
        ].compactMap { $0 }

        for path in possiblePaths {
            let url = URL(fileURLWithPath: path).standardized
            if fileManager.fileExists(atPath: url.path) {
                do {
                    let data = try Data(contentsOf: url)
                    let catalog = try JSONDecoder().decode(CatalogResponse.self, from: data)
                    servers = catalog.servers
                    // Also save to cache for future use
                    try? data.write(to: cacheURL)
                    print("[MCPCatalogService] Loaded \(servers.count) servers from local dev: \(url.path)")
                    return
                } catch {
                    print("[MCPCatalogService] Failed to load from \(url.path): \(error)")
                }
            }
        }

        print("[MCPCatalogService] No local dev catalog found")
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
