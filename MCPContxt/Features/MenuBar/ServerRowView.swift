//
//  ServerRowView.swift
//  MCPContxt
//
//  Individual server row in the popover list
//

import SwiftUI
import AppKit

struct ServerRowView: View {
    let server: MCPServer
    let onTap: () -> Void

    @ObservedObject private var statusChecker = MCPStatusChecker.shared
    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Server icon (fetched favicon or fallback SF Symbol)
                ServerIconView(
                    serverId: server.name,
                    serverURL: server.configuration.url,
                    serverType: server.type,
                    size: 24
                )

                // Server info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(server.name)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)

                        typeBadge
                    }

                    if let url = server.configuration.url {
                        Text(url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else if let command = server.configuration.command {
                        Text(command)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Connection status indicator (right side)
                statusIndicator
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovering ? Color.primary.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var typeBadge: some View {
        Text(server.type.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(4)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        let status = statusChecker.status(for: server.name)
        switch status {
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
                .help("Connected")
        case .needsAuth:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundColor(.orange)
                .help("Needs authentication - use in Claude Code to connect")
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.red)
                .help("Connection failed")
        case .unknown:
            Color.clear
                .frame(width: 12, height: 12)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ServerRowView(
            server: MCPServer(
                name: "github",
                type: .http,
                configuration: .http(url: "https://api.githubcopilot.com/mcp/")
            ),
            onTap: {}
        )

        ServerRowView(
            server: MCPServer(
                name: "slack",
                type: .http,
                configuration: .http(url: "https://mcp.slack.com/mcp")
            ),
            onTap: {}
        )

        ServerRowView(
            server: MCPServer(
                name: "local-server",
                type: .stdio,
                configuration: .stdio(command: "npx", args: ["-y", "@modelcontextprotocol/server-github"])
            ),
            onTap: {}
        )
    }
    .frame(width: 320)
    .background(Color(NSColor.windowBackgroundColor))
}
