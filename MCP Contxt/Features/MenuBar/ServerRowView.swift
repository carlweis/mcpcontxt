//
//  ServerRowView.swift
//  MCP Contxt
//
//  Individual server row in the popover list
//

import SwiftUI
import AppKit

struct ServerRowView: View {
    let server: MCPServer
    let onTap: () -> Void
    let onRestart: () -> Void
    let onViewLogs: () -> Void
    let onReAuth: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Status indicator
                statusIndicator

                // Server info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(server.name)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)

                        typeBadge
                    }

                    statusText
                }

                Spacer()

                // Quick actions (shown on hover)
                if isHovering {
                    quickActions
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var statusIndicator: some View {
        Group {
            if server.source == .enterprise {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if !server.isEnabled {
                Image(systemName: "circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: server.metadata.healthStatus.systemImage)
                    .font(.caption)
                    .foregroundColor(server.metadata.healthStatus.color)
            }
        }
        .frame(width: 16)
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

    private var statusText: some View {
        Group {
            if server.source == .enterprise {
                Text("Enterprise")
                    .foregroundColor(.secondary)
            } else if !server.isEnabled {
                Text("Disabled")
                    .foregroundColor(.secondary)
            } else if let message = server.metadata.healthMessage {
                Text(message)
                    .foregroundColor(server.metadata.healthStatus.color)
            } else {
                Text(server.metadata.healthStatus.displayName)
                    .foregroundColor(server.metadata.healthStatus.color)
            }
        }
        .font(.caption)
        .lineLimit(1)
    }

    private var quickActions: some View {
        HStack(spacing: 4) {
            if server.metadata.healthStatus == .needsAuth {
                actionButton(icon: "key.fill", action: onReAuth, help: "Re-authenticate")
            }

            if server.source != .enterprise {
                actionButton(icon: "arrow.clockwise", action: onRestart, help: "Restart")
            }

            actionButton(icon: "doc.text", action: onViewLogs, help: "View logs")
        }
    }

    private func actionButton(icon: String, action: @escaping () -> Void, help: String) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

#Preview {
    VStack(spacing: 0) {
        ServerRowView(
            server: MCPServer(
                name: "github",
                type: .stdio,
                configuration: .stdio(command: "npx", args: ["-y", "@modelcontextprotocol/server-github"])
            ),
            onTap: {},
            onRestart: {},
            onViewLogs: {},
            onReAuth: {}
        )

        ServerRowView(
            server: MCPServer(
                name: "slack",
                type: .http,
                configuration: .http(url: "https://mcp.slack.com/sse"),
                metadata: MCPServerMetadata(healthStatus: .needsAuth, healthMessage: "Token expired")
            ),
            onTap: {},
            onRestart: {},
            onViewLogs: {},
            onReAuth: {}
        )

        ServerRowView(
            server: MCPServer(
                name: "company-api",
                type: .http,
                configuration: .http(url: "https://api.company.com/mcp"),
                source: .enterprise
            ),
            onTap: {},
            onRestart: {},
            onViewLogs: {},
            onReAuth: {}
        )
    }
    .frame(width: 320)
    .background(Color(NSColor.windowBackgroundColor))
}
