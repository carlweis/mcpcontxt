//
//  ServerRegistry.swift
//  MCP Contxt
//
//  The source of truth for all MCP server configurations
//

import Foundation
import Combine
import SwiftUI

@MainActor
class ServerRegistry: ObservableObject {
    static let shared = ServerRegistry()

    @Published private(set) var servers: [MCPServer] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: Error?

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var registryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("MCP Contxt")
        return appDirectory.appendingPathComponent("servers.json")
    }

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard fileManager.fileExists(atPath: registryURL.path) else {
                servers = []
                return
            }

            let data = try Data(contentsOf: registryURL)
            let registry = try decoder.decode(ServerRegistryFile.self, from: data)
            servers = registry.servers
            lastError = nil
        } catch {
            lastError = error
            servers = []
        }
    }

    func save() async throws {
        // Ensure directory exists
        let directory = registryURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let registry = ServerRegistryFile(version: 1, servers: servers)
        let data = try encoder.encode(registry)
        try data.write(to: registryURL, options: .atomic)
    }

    func add(_ server: MCPServer) async throws {
        guard !servers.contains(where: { $0.name == server.name }) else {
            throw ServerRegistryError.duplicateName(server.name)
        }

        servers.append(server)
        try await save()
    }

    func update(_ server: MCPServer) async throws {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else {
            throw ServerRegistryError.serverNotFound(server.id)
        }

        var updatedServer = server
        updatedServer.metadata.lastModifiedAt = Date()
        servers[index] = updatedServer
        try await save()
    }

    func remove(_ server: MCPServer) async throws {
        guard server.source != .enterprise else {
            throw ServerRegistryError.cannotModifyEnterprise
        }

        servers.removeAll { $0.id == server.id }
        try await save()
    }

    func remove(at offsets: IndexSet) async throws {
        let serversToRemove = offsets.map { servers[$0] }

        for server in serversToRemove {
            guard server.source != .enterprise else {
                throw ServerRegistryError.cannotModifyEnterprise
            }
        }

        servers.remove(atOffsets: offsets)
        try await save()
    }

    func server(withName name: String) -> MCPServer? {
        servers.first { $0.name == name }
    }

    func server(withID id: UUID) -> MCPServer? {
        servers.first { $0.id == id }
    }

    func updateHealthStatus(for serverID: UUID, status: HealthStatus, message: String? = nil) async throws {
        guard let index = servers.firstIndex(where: { $0.id == serverID }) else {
            throw ServerRegistryError.serverNotFound(serverID)
        }

        servers[index].metadata.healthStatus = status
        servers[index].metadata.healthMessage = message
        servers[index].metadata.lastHealthCheckAt = Date()
        try await save()
    }

    func markSynced(for serverID: UUID) async throws {
        guard let index = servers.firstIndex(where: { $0.id == serverID }) else {
            throw ServerRegistryError.serverNotFound(serverID)
        }

        servers[index].metadata.lastSyncedAt = Date()
        try await save()
    }

    func importServers(_ newServers: [MCPServer], replacing: Bool = false) async throws {
        if replacing {
            // Replace servers with same name
            for newServer in newServers {
                if let existingIndex = servers.firstIndex(where: { $0.name == newServer.name }) {
                    servers[existingIndex] = newServer
                } else {
                    servers.append(newServer)
                }
            }
        } else {
            // Only add servers that don't exist
            for newServer in newServers {
                if !servers.contains(where: { $0.name == newServer.name }) {
                    servers.append(newServer)
                }
            }
        }

        try await save()
    }

    var enabledServers: [MCPServer] {
        servers.filter { $0.isEnabled }
    }

    var editableServers: [MCPServer] {
        servers.filter { $0.source.isEditable }
    }

    var enterpriseServers: [MCPServer] {
        servers.filter { $0.source == .enterprise }
    }

    var overallHealthStatus: HealthStatus {
        HealthStatus.overallStatus(from: servers)
    }
}

// MARK: - File Format

private struct ServerRegistryFile: Codable {
    let version: Int
    let servers: [MCPServer]
}

// MARK: - Errors

enum ServerRegistryError: LocalizedError {
    case duplicateName(String)
    case serverNotFound(UUID)
    case cannotModifyEnterprise

    var errorDescription: String? {
        switch self {
        case .duplicateName(let name):
            return "A server named '\(name)' already exists"
        case .serverNotFound(let id):
            return "Server with ID \(id) not found"
        case .cannotModifyEnterprise:
            return "Enterprise servers cannot be modified"
        }
    }
}
