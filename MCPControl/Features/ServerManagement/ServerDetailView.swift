//
//  ServerDetailView.swift
//  MCPControl
//
//  Detailed view of a server configuration
//

import SwiftUI
import AppKit

struct ServerDetailView: View {
    @Environment(\.dismiss) private var environmentDismiss
    @ObservedObject private var registry = ServerRegistry.shared
    @ObservedObject private var statusChecker = MCPStatusChecker.shared

    let server: MCPServer
    let onDismiss: (() -> Void)?

    init(server: MCPServer, onDismiss: (() -> Void)? = nil) {
        self.server = server
        self.onDismiss = onDismiss
    }

    private func dismiss() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            environmentDismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Details
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusSection
                    configurationSection
                    authSection
                }
                .padding()
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 450, height: 400)
    }

    private var header: some View {
        HStack(spacing: 12) {
            // Server icon
            ServerIconView(
                serverId: server.name,
                serverURL: server.configuration.url,
                serverType: server.type,
                size: 48
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(server.name)
                        .font(.headline)

                    Text(server.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }

                Text("Configured in ~/.claude.json")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding()
    }

    private var statusSection: some View {
        let status = statusChecker.status(for: server.name)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Connection Status")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                // Status icon
                Group {
                    switch status {
                    case .connected:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    case .needsAuth:
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    case .failed:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    case .unknown:
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .font(.title2)

                // Status text and action
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle(for: status))
                        .font(.headline)

                    Text(statusDescription(for: status))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(statusBackgroundColor(for: status))
            .cornerRadius(8)
        }
    }

    private func statusTitle(for status: MCPConnectionStatus) -> String {
        switch status {
        case .connected: return "Connected"
        case .needsAuth: return "Needs Authentication"
        case .failed: return "Connection Failed"
        case .unknown: return "Status Unknown"
        }
    }

    private func statusDescription(for status: MCPConnectionStatus) -> String {
        switch status {
        case .connected:
            return "This server is connected and ready to use in Claude Code."
        case .needsAuth:
            return "Open Claude Code and use this server to complete authentication."
        case .failed:
            return "Unable to connect. The server may be down or there may be a network issue."
        case .unknown:
            return "Click refresh to check the connection status."
        }
    }

    private func statusBackgroundColor(for status: MCPConnectionStatus) -> Color {
        switch status {
        case .connected: return Color.green.opacity(0.1)
        case .needsAuth: return Color.orange.opacity(0.1)
        case .failed: return Color.red.opacity(0.1)
        case .unknown: return Color.secondary.opacity(0.1)
        }
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                switch server.type {
                case .http, .sse:
                    configRow("URL", value: server.configuration.url ?? "N/A")

                    if let headers = server.configuration.headers, !headers.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Headers:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(Array(headers.keys), id: \.self) { key in
                                Text("  \(key): \(headers[key] ?? "")")
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }

                case .stdio:
                    configRow("Command", value: server.configuration.command ?? "N/A")

                    if let args = server.configuration.args, !args.isEmpty {
                        configRow("Arguments", value: args.joined(separator: " "))
                    }

                    if let env = server.configuration.env, !env.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Environment Variables:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(Array(env.keys), id: \.self) { key in
                                Text("  \(key)=***")
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func configRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Authentication")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                if server.type == .http || server.type == .sse {
                    Text("Authentication happens automatically in Claude Code. When you first use this server, Claude Code will open your browser to complete the OAuth flow.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("Just start using the server in Claude Code to authenticate.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("This stdio server runs locally and may require environment variables for authentication (like API tokens).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var footer: some View {
        HStack {
            Button(role: .destructive) {
                removeServer()
            } label: {
                Label("Remove", systemImage: "trash")
            }

            Spacer()
        }
        .padding()
    }

    private func removeServer() {
        print("[ServerDetailView] Removing server: \(server.name)")
        Task {
            do {
                try await registry.remove(server)
                print("[ServerDetailView] Server removed successfully")
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("[ServerDetailView] Failed to remove server: \(error)")
            }
        }
    }
}

#Preview {
    ServerDetailView(
        server: MCPServer(
            name: "linear",
            type: .http,
            configuration: .http(url: "https://mcp.linear.app/mcp")
        ),
        onDismiss: nil
    )
}
