//
//  ServerDetailView.swift
//  MCP Contxt
//
//  Detailed view of a server configuration
//

import SwiftUI
import AppKit

struct ServerDetailView: View {
    @Environment(\.dismiss) private var environmentDismiss
    @EnvironmentObject var registry: ServerRegistry

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
        HStack {
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
                if server.type == .http || server.type == .sse, let url = server.configuration.url {
                    Text("Most MCP servers use OAuth for authentication. Click the link below to authenticate with this service.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let authURL = URL(string: url) {
                        Link(destination: authURL) {
                            Label("Open \(server.name) to authenticate", systemImage: "arrow.up.forward")
                        }
                        .buttonStyle(.bordered)
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

            if let url = server.configuration.url, let authURL = URL(string: url) {
                Link(destination: authURL) {
                    Label("Connect", systemImage: "arrow.up.forward")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private func removeServer() {
        Task {
            try? await registry.remove(server)
            await MainActor.run {
                dismiss()
            }
        }
    }
}

#Preview {
    ServerDetailView(
        server: MCPServer(
            name: "github",
            type: .http,
            configuration: .http(url: "https://api.githubcopilot.com/mcp/")
        ),
        onDismiss: nil
    )
    .environmentObject(ServerRegistry.shared)
}
