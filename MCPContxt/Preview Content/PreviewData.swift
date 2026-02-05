//
//  PreviewData.swift
//  MCPContxt
//
//  Sample data for SwiftUI previews
//

import Foundation

enum PreviewData {
    static let githubServer = MCPServer(
        name: "github",
        type: .stdio,
        configuration: .stdio(
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-github"],
            env: ["GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxx"]
        ),
        metadata: MCPServerMetadata(healthStatus: .healthy)
    )

    static let slackServer = MCPServer(
        name: "slack",
        type: .http,
        configuration: .http(
            url: "https://mcp.slack.com/sse",
            headers: ["Authorization": "Bearer xoxb-xxx"]
        ),
        metadata: MCPServerMetadata(healthStatus: .healthy)
    )

    static let notionServer = MCPServer(
        name: "notion",
        type: .http,
        configuration: .http(url: "https://mcp.notion.so/mcp"),
        metadata: MCPServerMetadata(
            healthStatus: .needsAuth,
            healthMessage: "Token expired"
        )
    )

    static let postgresServer = MCPServer(
        name: "postgres",
        type: .stdio,
        configuration: .stdio(
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-postgres"]
        ),
        isEnabled: false,
        metadata: MCPServerMetadata(healthStatus: .disabled)
    )

    static let enterpriseServer = MCPServer(
        name: "company-api",
        type: .http,
        configuration: .http(url: "https://api.company.com/mcp"),
        syncTargets: [],
        metadata: MCPServerMetadata(healthStatus: .healthy),
        source: .enterprise
    )

    static let unhealthyServer = MCPServer(
        name: "failing-server",
        type: .http,
        configuration: .http(url: "https://broken.example.com/mcp"),
        metadata: MCPServerMetadata(
            healthStatus: .unhealthy,
            healthMessage: "Connection refused"
        )
    )

    static let allServers = [
        githubServer,
        slackServer,
        notionServer,
        postgresServer,
        enterpriseServer,
        unhealthyServer
    ]

    static let healthyServers = [
        githubServer,
        slackServer
    ]
}
