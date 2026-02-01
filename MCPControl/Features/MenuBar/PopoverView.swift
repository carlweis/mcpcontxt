//
//  PopoverView.swift
//  MCPControl
//
//  Main popover content showing server list and quick actions
//

import SwiftUI
import AppKit

struct PopoverView: View {
    @EnvironmentObject var registry: ServerRegistry
    @ObservedObject private var statusChecker = MCPStatusChecker.shared

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
        .onAppear {
            print("[PopoverView] onAppear - loading servers")
            Task {
                await registry.loadFromClaudeConfig()
                await statusChecker.refresh()
                print("[PopoverView] onAppear load complete, showing \(registry.servers.count) servers")
            }
        }
    }

    private var header: some View {
        HStack {
            Text("MCP Control")
                .font(.headline)

            Spacer()

            if registry.isLoading || statusChecker.isChecking {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            } else {
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh servers and check status")
            }

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

    private func refresh() {
        print("[PopoverView] Refresh button tapped")
        Task {
            await registry.loadFromClaudeConfig()
            await statusChecker.refresh()
            print("[PopoverView] Refresh complete, now showing \(registry.servers.count) servers")
        }
    }

    private var serverList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(registry.servers) { server in
                    ServerRowView(
                        server: server,
                        onTap: { openServerDetail(server) }
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

            Text("Browse the catalog to add MCP servers for use with Claude Code.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Browse Catalog") {
                NotificationCenter.default.post(name: .openBrowse, object: nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var footer: some View {
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

            if !registry.servers.isEmpty {
                Text("\(registry.servers.count) server\(registry.servers.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit MCP Control")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

#Preview {
    PopoverView()
        .environmentObject(ServerRegistry.shared)
}
