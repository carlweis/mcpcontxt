//
//  ServerListView.swift
//  MCPControl
//
//  Full server list view for settings
//

import SwiftUI

struct ServerListView: View {
    @EnvironmentObject var registry: ServerRegistry

    @State private var selectedServerID: UUID?
    @State private var showingAddServer = false
    @State private var serverToEdit: MCPServer?
    @State private var serverToDelete: MCPServer?
    @State private var showingDeleteConfirmation = false
    @State private var searchText = ""

    var filteredServers: [MCPServer] {
        if searchText.isEmpty {
            return registry.servers
        }
        return registry.servers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Server List
            if registry.servers.isEmpty {
                emptyState
            } else {
                serverTable
            }
        }
        .sheet(isPresented: $showingAddServer) {
            AddServerView()
                .environmentObject(registry)
        }
        .sheet(item: $serverToEdit) { server in
            AddServerView(editingServer: server)
                .environmentObject(registry)
        }
        .alert("Delete Server", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let server = serverToDelete {
                    deleteServer(server)
                }
            }
        } message: {
            if let server = serverToDelete {
                Text("Are you sure you want to delete '\(server.name)'? This will remove it from ~/.claude.json.")
            }
        }
    }

    private var toolbar: some View {
        HStack {
            TextField("Search servers...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)

            Spacer()

            Button(action: { showingAddServer = true }) {
                Label("Add Server", systemImage: "plus")
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Servers Configured")
                .font(.title2)

            Text("Add an MCP server to get started.")
                .foregroundColor(.secondary)

            Button(action: { showingAddServer = true }) {
                Label("Add Server", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var serverTable: some View {
        Table(filteredServers, selection: $selectedServerID) {
            TableColumn("Name") { server in
                HStack(spacing: 8) {
                    ServerIconView(
                        serverId: server.name,
                        serverURL: server.configuration.url,
                        serverType: server.type,
                        size: 20
                    )

                    Text(server.name)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .width(min: 120, ideal: 170)

            TableColumn("Type") { server in
                Text(server.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            .width(60)

            TableColumn("URL/Command") { server in
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
            .width(min: 150, ideal: 250)

            TableColumn("Actions") { server in
                HStack(spacing: 8) {
                    Button(action: { serverToEdit = server }) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                    .help("Edit")

                    Button(action: {
                        serverToDelete = server
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
            }
            .width(70)
        }
        .contextMenu(forSelectionType: UUID.self) { selection in
            if let serverID = selection.first,
               let server = registry.server(withID: serverID) {
                Button("Edit") {
                    serverToEdit = server
                }
                Button("Delete", role: .destructive) {
                    serverToDelete = server
                    showingDeleteConfirmation = true
                }
            }
        } primaryAction: { selection in
            if let serverID = selection.first,
               let server = registry.server(withID: serverID) {
                serverToEdit = server
            }
        }
    }

    private func deleteServer(_ server: MCPServer) {
        Task {
            try? await registry.remove(server)
        }
    }
}

#Preview {
    ServerListView()
        .environmentObject(ServerRegistry.shared)
        .frame(width: 600, height: 400)
}
