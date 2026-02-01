//
//  BrowseServersView.swift
//  MCPControl
//
//  Browse and add MCP servers from the remote catalog
//

import SwiftUI

struct BrowseServersView: View {
    @Environment(\.dismiss) private var environmentDismiss
    @EnvironmentObject var registry: ServerRegistry
    @ObservedObject private var catalogService = MCPCatalogService.shared

    let onDismiss: (() -> Void)?

    @State private var searchText = ""
    @State private var addedServers: Set<String> = []
    @State private var filterOption: FilterOption = .all

    enum FilterOption: String, CaseIterable {
        case all = "All"
        case installed = "Installed"
        case notInstalled = "Not Installed"
    }

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
        let searched = catalogService.search(searchText)

        switch filterOption {
        case .all:
            return searched
        case .installed:
            return searched.filter { isServerInstalled($0) }
        case .notInstalled:
            return searched.filter { !isServerInstalled($0) }
        }
    }

    private func isServerInstalled(_ server: MCPCatalogServer) -> Bool {
        addedServers.contains(server.id) || registry.server(withName: server.id) != nil
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
            if catalogService.isLoading && catalogService.servers.isEmpty {
                loadingState
            } else if catalogService.servers.isEmpty {
                emptyState
            } else {
                serverList
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 600, height: 550)
        .onAppear {
            // Mark already-added servers
            let existingNames = Set(registry.servers.map { $0.name })
            addedServers = existingNames

            // Refresh catalog on appear
            Task {
                await catalogService.refresh()
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading servers...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("Unable to load servers")
                .font(.headline)

            if let error = catalogService.lastError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Try Again") {
                Task {
                    await catalogService.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Browse MCP Servers")
                    .font(.headline)

                Text("\(catalogService.servers.count) servers available from the MCP registry")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if catalogService.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            } else {
                Button(action: {
                    Task {
                        await catalogService.refresh()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh catalog")
            }

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding()
    }

    private var searchBar: some View {
        VStack(spacing: 8) {
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

                Text("\(filteredServers.count) servers")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Filter picker
            Picker("Filter", selection: $filterOption) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding()
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
                        .background(server.isStdio ? Color.purple.opacity(0.2) : Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }

                Text(server.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Show URL for remote servers, command for stdio
                if let url = server.url {
                    Text(url)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if let command = server.command, let args = server.args {
                    Text("\(command) \(args.joined(separator: " "))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Show required env vars for stdio servers
                if server.isStdio, let envVars = server.env, !envVars.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "key")
                            .font(.caption2)
                        Text("Requires: \(envVars.joined(separator: ", "))")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
            }

            Spacer()

            // Actions
            VStack(spacing: 8) {
                if addedServers.contains(server.id) || registry.server(withName: server.id) != nil {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if server.isStdio {
                    // Stdio servers - show configure button
                    Button("Configure") {
                        NotificationCenter.default.post(name: .openStdioServerConfig, object: server)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Configure this server with required credentials")
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
