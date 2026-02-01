//
//  ImportServersView.swift
//  MCPControl
//
//  Show current servers from ~/.claude.json
//

import SwiftUI

struct ImportServersView: View {
    @Environment(\.dismiss) private var environmentDismiss
    @EnvironmentObject var registry: ServerRegistry

    let onDismiss: (() -> Void)?

    @State private var isLoading = true

    init(onDismiss: (() -> Void)? = nil) {
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

            // Content
            if isLoading {
                loadingView
            } else if registry.servers.isEmpty {
                emptyState
            } else {
                serverListView
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 500, height: 450)
        .onAppear {
            Task {
                await registry.loadFromClaudeConfig()
                isLoading = false
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your MCP Servers")
                    .font(.headline)

                Text("Servers configured in ~/.claude.json")
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

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading servers...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No MCP Servers Found")
                .font(.title2)

            VStack(alignment: .leading, spacing: 8) {
                Text("No servers configured in ~/.claude.json")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Use the Browse button to discover and add MCP servers.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            Button("Browse Catalog") {
                dismiss()
                NotificationCenter.default.post(name: .openBrowse, object: nil)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var serverListView: some View {
        List {
            ForEach(registry.servers) { server in
                serverRow(server)
            }
        }
    }

    private func serverRow(_ server: MCPServer) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(server.name)
                        .font(.system(.body, design: .monospaced))

                    Text(server.type.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
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
        }
        .padding(.vertical, 4)
    }

    private var footer: some View {
        HStack {
            Text("Config: ~/.claude.json")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button("Refresh") {
                Task {
                    isLoading = true
                    await registry.loadFromClaudeConfig()
                    isLoading = false
                }
            }
        }
        .padding()
    }
}

#Preview {
    ImportServersView()
        .environmentObject(ServerRegistry.shared)
}
