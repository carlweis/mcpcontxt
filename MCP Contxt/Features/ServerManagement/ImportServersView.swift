//
//  ImportServersView.swift
//  MCP Contxt
//
//  Import servers from existing configurations
//

import SwiftUI

struct ImportServersView: View {
    @Environment(\.dismiss) private var environmentDismiss
    @EnvironmentObject var registry: ServerRegistry

    let onDismiss: (() -> Void)?

    @State private var discoveryResult: DiscoveryResult?
    @State private var isLoading = true
    @State private var selectedServers: Set<String> = []
    @State private var replaceExisting = false
    @State private var isImporting = false
    @State private var errorMessage: String?

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
            } else if let result = discoveryResult {
                if result.hasServers {
                    serverSelectionView(result)
                } else {
                    emptyState
                }
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 500, height: 450)
        .onAppear(perform: discoverServers)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import MCP Servers")
                    .font(.headline)

                Text("Discover and import servers from existing configurations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Cancel") {
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

            Text("Scanning for MCP configurations...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No MCP Servers Found")
                .font(.title2)

            VStack(alignment: .leading, spacing: 8) {
                Text("Looking for configurations in:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    configPathRow("Claude Desktop", path: "~/Library/Application Support/Claude/claude_desktop_config.json")
                    configPathRow("Claude Code", path: "~/.claude.json")
                }
                .font(.caption2)
                .foregroundColor(.secondary)

                Text("Note: Claude Desktop's \"Connectors\" (Figma, Slack, etc.) use a different system and cannot be imported.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            // Always show discovery status for debugging
            VStack(alignment: .leading, spacing: 4) {
                if let error = discoveryResult?.claudeDesktopError {
                    Text("Claude Desktop error: \(error.localizedDescription)")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("Claude Desktop: \(discoveryResult?.claudeDesktopServers.count ?? 0) servers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let error = discoveryResult?.claudeCodeError {
                    Text("Claude Code error: \(error.localizedDescription)")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("Claude Code: \(discoveryResult?.claudeCodeServers.count ?? 0) servers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func configPathRow(_ name: String, path: String) -> some View {
        HStack {
            Text(name + ":")
                .frame(width: 100, alignment: .leading)
            Text(path)
                .font(.system(.caption2, design: .monospaced))
        }
    }

    private func serverSelectionView(_ result: DiscoveryResult) -> some View {
        VStack(spacing: 0) {
            // Sources summary
            HStack(spacing: 16) {
                sourceBadge("Claude Desktop", count: result.claudeDesktopServers.count, error: result.claudeDesktopError)
                sourceBadge("Claude Code", count: result.claudeCodeServers.count, error: result.claudeCodeError)
                sourceBadge("Enterprise", count: result.enterpriseServers.count, error: result.enterpriseError)
            }
            .padding()

            Divider()

            // Server list
            List(result.mergedServers, id: \.name, selection: $selectedServers) { server in
                serverRow(server)
            }

            // Options
            HStack {
                Toggle("Replace existing servers with same name", isOn: $replaceExisting)
                    .font(.caption)

                Spacer()

                Button("Select All") {
                    selectedServers = Set(result.mergedServers.map { $0.name })
                }

                Button("Select None") {
                    selectedServers.removeAll()
                }
            }
            .padding()
        }
    }

    private func sourceBadge(_ name: String, count: Int, error: Error?) -> some View {
        VStack(spacing: 4) {
            if let error = error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            } else {
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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

                Text("From: \(server.source.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if registry.server(withName: server.name) != nil {
                Label("Exists", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private var footer: some View {
        HStack {
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Refresh") {
                discoverServers()
            }
            .disabled(isLoading)

            Button("Import Selected") {
                importSelected()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImporting || selectedServers.isEmpty)
        }
        .padding()
    }

    private func discoverServers() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await ConfigurationManager.shared.discoverExistingServers()

                await MainActor.run {
                    discoveryResult = result
                    // Pre-select all servers
                    selectedServers = Set(result.mergedServers.map { $0.name })
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

    private func importSelected() {
        guard let result = discoveryResult else { return }

        isImporting = true
        errorMessage = nil

        let serversToImport = result.mergedServers.filter { selectedServers.contains($0.name) }

        Task {
            do {
                try await ConfigurationManager.shared.importDiscoveredServers(serversToImport, replacing: replaceExisting)
                try await SyncService.shared.sync()

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }
}

#Preview {
    ImportServersView()
        .environmentObject(ServerRegistry.shared)
}
