//
//  MCPCatalog.swift
//  MCPContxt
//
//  MCP server catalog - uses MCPCatalogService for remote data
//

import Foundation

enum AuthType: String, Codable, Hashable {
    case none
    case oauth
    case apiKey
}

struct CatalogAlternative: Codable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let transport: String
    let command: String?
    let args: [String]?
    let env: [String]?
    let url: String?
    let setupUrl: String?
    let notes: String?

    var transportType: MCPCatalogServer.TransportType {
        MCPCatalogServer.TransportType(rawValue: transport) ?? .http
    }

    var isStdio: Bool {
        transport == "stdio"
    }
}

struct MCPCatalogServer: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let transport: TransportType

    // For HTTP/SSE servers
    let url: String?

    // For stdio servers
    let command: String?
    let args: [String]?
    let env: [String]?

    // Additional metadata
    let setupUrl: String?
    let documentationUrl: String?
    let githubUrl: String?
    let requirements: [String]?
    let installCommand: String?

    // Auth and alternatives
    let auth: AuthType?
    let alternatives: [CatalogAlternative]?

    // Whether this is an official/verified server
    let official: Bool

    enum TransportType: String {
        case http
        case sse
        case stdio
    }

    var isRemote: Bool {
        transport == .http || transport == .sse
    }

    var isStdio: Bool {
        transport == .stdio
    }

    var isOAuth: Bool {
        auth == .oauth
    }
}

struct MCPCatalog {

    static var servers: [MCPCatalogServer] {
        MCPCatalogService.shared.servers
    }

    static func search(_ query: String) -> [MCPCatalogServer] {
        MCPCatalogService.shared.search(query)
    }

    static func server(withId id: String) -> MCPCatalogServer? {
        MCPCatalogService.shared.servers.first { $0.id == id }
    }
}
