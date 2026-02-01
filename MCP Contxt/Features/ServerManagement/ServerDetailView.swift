//
//  ServerDetailView.swift
//  MCP Contxt
//
//  Detailed view of a server with logs and actions
//

import SwiftUI
import AppKit

struct ServerDetailView: View {
    @Environment(\.dismiss) private var environmentDismiss

    let server: MCPServer
    let onDismiss: (() -> Void)?

    @State private var logs: [String] = []
    @State private var errors: [LogError] = []
    @State private var isLoading = true
    @State private var selectedTab = 0

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

            // Tabs
            TabView(selection: $selectedTab) {
                detailsTab
                    .tabItem { Label("Details", systemImage: "info.circle") }
                    .tag(0)

                logsTab
                    .tabItem { Label("Logs", systemImage: "doc.text") }
                    .tag(1)

                errorsTab
                    .tabItem { Label("Errors", systemImage: "exclamationmark.triangle") }
                    .tag(2)
            }
            .padding()

            Divider()

            // Footer
            footer
        }
        .frame(width: 500, height: 450)
        .onAppear(perform: loadData)
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

                    if server.source == .enterprise {
                        Label("Enterprise", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: server.metadata.healthStatus.systemImage)
                        .foregroundColor(server.metadata.healthStatus.color)

                    Text(server.metadata.healthStatus.displayName)
                        .foregroundColor(.secondary)

                    if let message = server.metadata.healthMessage {
                        Text("- \(message)")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding()
    }

    private var detailsTab: some View {
        Form {
            Section("Configuration") {
                switch server.type {
                case .http, .sse:
                    LabeledContent("URL", value: server.configuration.url ?? "N/A")

                    if let headers = server.configuration.headers, !headers.isEmpty {
                        LabeledContent("Headers") {
                            VStack(alignment: .trailing, spacing: 4) {
                                ForEach(Array(headers.keys), id: \.self) { key in
                                    Text("\(key): \(headers[key] ?? "")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                case .stdio:
                    LabeledContent("Command", value: server.configuration.command ?? "N/A")

                    if let args = server.configuration.args, !args.isEmpty {
                        LabeledContent("Arguments", value: args.joined(separator: " "))
                    }

                    if let env = server.configuration.env, !env.isEmpty {
                        LabeledContent("Environment") {
                            VStack(alignment: .trailing, spacing: 4) {
                                ForEach(Array(env.keys), id: \.self) { key in
                                    Text("\(key)=***")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section("Sync Targets") {
                ForEach(SyncTarget.allCases, id: \.self) { target in
                    HStack {
                        Text(target.displayName)
                        Spacer()
                        if server.syncTargets.contains(target) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("Metadata") {
                LabeledContent("Created", value: server.metadata.createdAt.formatted())
                LabeledContent("Modified", value: server.metadata.lastModifiedAt.formatted())

                if let lastSynced = server.metadata.lastSyncedAt {
                    LabeledContent("Last Synced", value: lastSynced.formatted())
                }

                if let lastCheck = server.metadata.lastHealthCheckAt {
                    LabeledContent("Last Health Check", value: lastCheck.formatted())
                }

                LabeledContent("Source", value: server.source.displayName)
            }
        }
        .formStyle(.grouped)
    }

    private var logsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if logs.isEmpty {
                emptyLogsState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(logs.indices, id: \.self) { index in
                            Text(logs[index])
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(8)
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    private var errorsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if errors.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    Text("No Recent Errors")
                        .font(.headline)
                    Text("This server has no errors in the recent logs.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(errors) { error in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error.relativeTime)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(error.message)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var emptyLogsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No Logs Available")
                .font(.headline)
            Text("Log files for this server were not found.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            if server.type == .stdio && ProcessMonitor.shared.isClaudeDesktopInstalled {
                Button("Restart Claude Desktop") {
                    Task {
                        _ = await ProcessMonitor.shared.restartClaudeDesktop()
                    }
                }
            }

            Spacer()

            Button("Refresh") {
                loadData()
            }
        }
        .padding()
    }

    private func loadData() {
        isLoading = true

        Task {
            let logLines = LogParser.shared.readRecentLogs(for: server.name, lines: 100)
            let logErrors = LogParser.shared.getRecentErrors(for: server.name)

            await MainActor.run {
                logs = logLines
                errors = logErrors
                isLoading = false
            }
        }
    }
}

#Preview {
    ServerDetailView(
        server: MCPServer(
            name: "github",
            type: .stdio,
            configuration: .stdio(
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-github"],
                env: ["GITHUB_TOKEN": "ghp_xxx"]
            )
        ),
        onDismiss: nil
    )
}
