//
//  ServerListView.swift
//  MCP Contxt
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
                Text("Are you sure you want to delete '\(server.name)'? This will also remove it from synced configurations.")
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
            TableColumn("Status") { server in
                HStack(spacing: 6) {
                    Image(systemName: server.metadata.healthStatus.systemImage)
                        .foregroundColor(server.metadata.healthStatus.color)

                    if server.source == .enterprise {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 40)
            }
            .width(50)

            TableColumn("Name") { server in
                Text(server.name)
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 100, ideal: 150)

            TableColumn("Type") { server in
                Text(server.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            .width(60)

            TableColumn("Sync Targets") { server in
                HStack(spacing: 4) {
                    ForEach(Array(server.syncTargets), id: \.self) { target in
                        Text(target == .claudeDesktop ? "Desktop" : "CLI")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            .width(min: 100, ideal: 140)

            TableColumn("Source") { server in
                Text(server.source.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(80)

            TableColumn("Actions") { server in
                HStack(spacing: 8) {
                    if server.source.isEditable {
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
            }
            .width(70)
        }
        .contextMenu(forSelectionType: UUID.self) { selection in
            if let serverID = selection.first,
               let server = registry.server(withID: serverID),
               server.source.isEditable {
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
               let server = registry.server(withID: serverID),
               server.source.isEditable {
                serverToEdit = server
            }
        }
    }

    private func deleteServer(_ server: MCPServer) {
        Task {
            try? await SyncService.shared.removeAndSync(server)
        }
    }
}

#Preview {
    ServerListView()
        .environmentObject(ServerRegistry.shared)
        .frame(width: 600, height: 400)
}
