//
//  BrowseServersView.swift
//  MCP Contxt
//
//  Browse and add MCP servers from the official registry
//

import SwiftUI

struct BrowseServersView: View {
    @Environment(\.dismiss) private var environmentDismiss
    @EnvironmentObject var registry: ServerRegistry

    let onDismiss: (() -> Void)?

    @State private var servers: [MCPRegistryService.DiscoveredServer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var filterClaudeCode = false
    @State private var filterClaudeDesktop = false
    @State private var addingServer: MCPRegistryService.DiscoveredServer?
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

    var filteredServers: [MCPRegistryService.DiscoveredServer] {
        servers.filter { server in
            // Search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let nameMatch = server.name.lowercased().contains(searchLower)
                let descMatch = server.description?.lowercased().contains(searchLower) ?? false
                if !nameMatch && !descMatch {
                    return false
                }
            }

            // Compatibility filters
            if filterClaudeCode && !server.worksWithClaudeCode {
                return false
            }
            if filterClaudeDesktop && !server.worksWithClaudeDesktop {
                return false
            }

            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Filters
            filtersBar

            Divider()

            // Content
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else {
                serverList
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 600, height: 550)
        .onAppear(perform: loadServers)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Browse MCP Servers")
                    .font(.headline)

                Text("Discover servers from the official Anthropic MCP registry")
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

    private var filtersBar: some View {
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

            Toggle("Claude Code", isOn: $filterClaudeCode)
                .toggleStyle(.checkbox)
                .font(.caption)

            Toggle("Claude Desktop", isOn: $filterClaudeDesktop)
                .toggleStyle(.checkbox)
                .font(.caption)

            Spacer()

            Text("\(filteredServers.count) servers")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading MCP registry...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Failed to Load Registry")
                .font(.title2)

            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                loadServers()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func serverCard(_ server: MCPRegistryService.DiscoveredServer) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            VStack {
                Image(systemName: serverIcon(for: server))
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(server.name)
                        .font(.headline)

                    Text(server.transportType)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)

                    if server.worksWithClaudeCode {
                        Image(systemName: "terminal")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .help("Works with Claude Code")
                    }

                    if server.worksWithClaudeDesktop {
                        Image(systemName: "desktopcomputer")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .help("Works with Claude Desktop")
                    }
                }

                if let description = server.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if let url = server.preferredURL {
                    Text(url)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Actions
            VStack(spacing: 8) {
                if addedServers.contains(server.id) || registry.server(withName: server.name) != nil {
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

                if let docURL = server.documentationURL, let url = URL(string: docURL) {
                    Link(destination: url) {
                        Label("Docs", systemImage: "doc.text")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func serverIcon(for server: MCPRegistryService.DiscoveredServer) -> String {
        let name = server.name.lowercased()

        if name.contains("github") { return "chevron.left.forwardslash.chevron.right" }
        if name.contains("slack") { return "bubble.left.and.bubble.right" }
        if name.contains("notion") { return "doc.text" }
        if name.contains("linear") { return "list.bullet.rectangle" }
        if name.contains("figma") { return "paintpalette" }
        if name.contains("sentry") { return "exclamationmark.triangle" }
        if name.contains("postgres") || name.contains("database") || name.contains("sql") { return "cylinder" }
        if name.contains("google") { return "g.circle" }
        if name.contains("jira") || name.contains("atlassian") { return "checklist" }
        if name.contains("asana") { return "list.bullet.clipboard" }
        if name.contains("file") || name.contains("fs") { return "folder" }
        if name.contains("browser") || name.contains("playwright") { return "globe" }
        if name.contains("git") { return "arrow.triangle.branch" }

        return "server.rack"
    }

    private var footer: some View {
        HStack {
            if !addedServers.isEmpty {
                Text("\(addedServers.count) server(s) added")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Spacer()

            Button("Refresh") {
                loadServers()
            }
            .disabled(isLoading)
        }
        .padding()
    }

    private func loadServers() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let fetchedServers = try await MCPRegistryService.shared.fetchServers()

                await MainActor.run {
                    servers = fetchedServers
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func addServer(_ server: MCPRegistryService.DiscoveredServer) {
        Task {
            do {
                let mcpServer: MCPServer

                if let httpURL = server.httpURL {
                    mcpServer = MCPServer(
                        name: server.name.lowercased().replacingOccurrences(of: " ", with: "-"),
                        type: .http,
                        configuration: .http(url: httpURL, headers: nil),
                        isEnabled: true,
                        syncTargets: [.claudeDesktop, .claudeCodeUser]
                    )
                } else if let sseURL = server.sseURL {
                    mcpServer = MCPServer(
                        name: server.name.lowercased().replacingOccurrences(of: " ", with: "-"),
                        type: .sse,
                        configuration: .http(url: sseURL, headers: nil),
                        isEnabled: true,
                        syncTargets: [.claudeDesktop, .claudeCodeUser]
                    )
                } else if let stdioCommand = server.stdioCommand {
                    let parts = stdioCommand.components(separatedBy: " ")
                    let command = parts.first ?? stdioCommand
                    let args = Array(parts.dropFirst())

                    mcpServer = MCPServer(
                        name: server.name.lowercased().replacingOccurrences(of: " ", with: "-"),
                        type: .stdio,
                        configuration: .stdio(command: command, args: args.isEmpty ? nil : args, env: nil),
                        isEnabled: true,
                        syncTargets: [.claudeDesktop, .claudeCodeUser]
                    )
                } else {
                    return
                }

                try await registry.add(mcpServer)
                try await SyncService.shared.syncServer(mcpServer)

                await MainActor.run {
                    addedServers.insert(server.id)
                }
            } catch {
                // Handle error silently for now
            }
        }
    }
}

#Preview {
    BrowseServersView()
        .environmentObject(ServerRegistry.shared)
}
