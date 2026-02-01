//
//  PopoverView.swift
//  MCP Contxt
//
//  Main popover content showing server list and quick actions
//

import SwiftUI
import AppKit

struct PopoverView: View {
    @EnvironmentObject var registry: ServerRegistry

    @ObservedObject private var syncService = SyncService.shared
    @ObservedObject private var configManager = ConfigurationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Server List
            if registry.servers.isEmpty {
                emptyState
            } else {
                serverList
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            Text("MCP Contxt")
                .font(.headline)

            Spacer()

            Button(action: openSettings) {
                Image(systemName: "gear")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    private var serverList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(registry.servers) { server in
                    ServerRowView(
                        server: server,
                        onTap: { openServerDetail(server) },
                        onRestart: { restartServer(server) },
                        onViewLogs: { openServerDetail(server) },
                        onReAuth: { openServerDetail(server) }
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 300)
    }

    private func openServerDetail(_ server: MCPServer) {
        NotificationCenter.default.post(name: .openServerDetail, object: server)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("No MCP Servers")
                .font(.headline)

            Text("Browse the MCP registry, add a server manually, or import existing configurations.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 8) {
                Button("Browse Registry") {
                    NotificationCenter.default.post(name: .openBrowse, object: nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Import Existing") {
                    NotificationCenter.default.post(name: .openImport, object: nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { NotificationCenter.default.post(name: .openAddServer, object: nil) }) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: { NotificationCenter.default.post(name: .openBrowse, object: nil) }) {
                    Label("Browse", systemImage: "globe")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(action: syncAll) {
                    if syncService.isSyncing {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(syncService.isSyncing || registry.servers.isEmpty)
            }

            syncStatusBar
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var syncStatusBar: some View {
        HStack(spacing: 12) {
            ForEach(SyncTarget.allCases, id: \.self) { target in
                HStack(spacing: 4) {
                    Image(systemName: syncIcon(for: target))
                        .font(.caption2)
                        .foregroundColor(syncColor(for: target))

                    Text(target.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .help(target.statusDescription)
            }

            Spacer()

            if let lastSync = syncService.lastSyncAt {
                Text(lastSync.relativeTimeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func syncIcon(for target: SyncTarget) -> String {
        // Check if target is available first
        if !target.isAvailable {
            return "minus.circle"
        }

        // Config file doesn't exist yet - show pending state
        if !target.configFileExists {
            return "circle.dashed"
        }

        if let status = configManager.syncStatuses[target] {
            if status.error != nil && status.error != "Config not created" {
                return "exclamationmark.circle.fill"
            }
            return status.isSynced ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath.circle"
        }
        return "circle"
    }

    private func syncColor(for target: SyncTarget) -> Color {
        // Check if target is available first
        if !target.isAvailable {
            return .secondary
        }

        // Config file doesn't exist yet - show neutral/pending state
        if !target.configFileExists {
            return .secondary
        }

        if let status = configManager.syncStatuses[target] {
            if status.error != nil && status.error != "Config not created" {
                return .orange
            }
            return status.isSynced ? .green : .yellow
        }
        return .secondary
    }

    private func syncAll() {
        Task {
            try? await syncService.sync()
        }
    }

    private func restartServer(_ server: MCPServer) {
        Task {
            if ProcessMonitor.shared.isClaudeDesktopRunning {
                _ = await ProcessMonitor.shared.restartClaudeDesktop()
            }
        }
    }

}

#Preview {
    PopoverView()
        .environmentObject(ServerRegistry.shared)
}
