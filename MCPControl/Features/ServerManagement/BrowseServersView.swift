//
//  BrowseServersView.swift
//  MCPControl
//
//  Browse and add MCP servers from the static catalog
//

import SwiftUI

struct BrowseServersView: View {
    @Environment(\.dismiss) private var environmentDismiss
    @EnvironmentObject var registry: ServerRegistry

    let onDismiss: (() -> Void)?

    @State private var searchText = ""
    @State private var addedServers: Set<String> = []

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

    var filteredServers: [MCPCatalogServer] {
        MCPCatalog.search(searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Search bar
            searchBar

            Divider()

            // Server list
            serverList

            Divider()

            // Footer
            footer
        }
        .frame(width: 600, height: 550)
        .onAppear {
            // Mark already-added servers
            let existingNames = Set(registry.servers.map { $0.name })
            addedServers = existingNames
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Browse MCP Servers")
                    .font(.headline)

                Text("\(MCPCatalog.servers.count) servers available from the MCP registry")
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

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search servers...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            Spacer()

            Text("\(filteredServers.count) servers")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var serverList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredServers) { server in
                    serverCard(server)
                }
            }
            .padding()
        }
    }

    private func serverCard(_ server: MCPCatalogServer) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon (fetched favicon or fallback SF Symbol)
            ServerIconView(catalogServer: server, size: 40)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(server.name)
                        .font(.headline)

                    Text(server.transport.rawValue.uppercased())
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }

                Text(server.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text(server.url)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Actions
            VStack(spacing: 8) {
                if addedServers.contains(server.id) || registry.server(withName: server.id) != nil {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Button("Add") {
                        addServer(server)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var footer: some View {
        HStack {
            if !addedServers.isEmpty {
                Text("\(addedServers.count) server(s) configured")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private func addServer(_ server: MCPCatalogServer) {
        do {
            let config = MCPServerConfig(
                type: server.transport == .sse ? "sse" : "http",
                url: server.url
            )
            try ClaudeConfigService.shared.addServer(name: server.id, config: config)

            // Reload registry from file
            Task {
                await registry.loadFromClaudeConfig()
            }

            addedServers.insert(server.id)
        } catch {
            print("[BrowseServersView] Failed to add server: \(error)")
        }
    }
}

#Preview {
    BrowseServersView()
        .environmentObject(ServerRegistry.shared)
}
