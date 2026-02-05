//
//  MCPCatalog.swift
//  MCPContxt
//
//  MCP server catalog - uses MCPCatalogService for remote data
//

import Foundation

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
    let setupUrl: String?

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
}

struct MCPCatalog {

    static var servers: [MCPCatalogServer] {
        MCPCatalogService.shared.servers
    }

    static func search(_ query: String) -> [MCPCatalogServer] {
        MCPCatalogService.shared.search(query)
    }
}
