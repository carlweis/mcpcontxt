//
//  AddStdioServerView.swift
//  MCPContxt
//
//  Configure and add a stdio MCP server with environment variables
//

import SwiftUI

struct AddStdioServerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var registry: ServerRegistry

    let catalogServer: MCPCatalogServer
    let onDismiss: (() -> Void)?

    @State private var envValues: [String: String] = [:]
    @State private var isAdding = false
    @State private var errorMessage: String?

    init(catalogServer: MCPCatalogServer, onDismiss: (() -> Void)? = nil) {
        self.catalogServer = catalogServer
        self.onDismiss = onDismiss
    }

    private func close() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Server info
                    serverInfoSection

                    // Environment variables
                    if let envVars = catalogServer.env, !envVars.isEmpty {
                        envVarsSection(envVars)
                    }

                    // Command preview
                    commandPreviewSection

                    // Error message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 500, height: 450)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ServerIconView(catalogServer: catalogServer, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("Configure \(catalogServer.name)")
                    .font(.headline)

                Text("Local stdio server")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Cancel") {
                close()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding()
    }

    private var serverInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Text(catalogServer.description)
                .font(.body)

            if let setupUrl = catalogServer.setupUrl, let url = URL(string: setupUrl) {
                Button(action: { NSWorkspace.shared.open(url) }) {
                    Label("View Documentation", systemImage: "book")
                }
                .buttonStyle(.link)
                .controlSize(.small)
            }
        }
    }

    private func envVarsSection(_ envVars: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environment Variables")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Text("Enter the required credentials. These will be stored in ~/.claude.json")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(envVars, id: \.self) { envVar in
                VStack(alignment: .leading, spacing: 4) {
                    Text(envVar)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)

                    SecureField("Enter value...", text: binding(for: envVar))
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var commandPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Command")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if let command = catalogServer.command, let args = catalogServer.args {
                Text("\(command) \(args.joined(separator: " "))")
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()

            Button(action: addServer) {
                if isAdding {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Text("Add Server")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAdding || !canAdd)
        }
        .padding()
    }

    private var canAdd: Bool {
        guard let envVars = catalogServer.env else { return true }
        return envVars.allSatisfy { envVar in
            !(envValues[envVar] ?? "").isEmpty
        }
    }

    private func binding(for envVar: String) -> Binding<String> {
        Binding(
            get: { envValues[envVar] ?? "" },
            set: { envValues[envVar] = $0 }
        )
    }

    private func addServer() {
        guard let command = catalogServer.command,
              let args = catalogServer.args else {
            errorMessage = "Invalid server configuration"
            return
        }

        isAdding = true
        errorMessage = nil

        let config = MCPServerConfig(
            type: "stdio",
            url: nil,
            headers: nil,
            command: command,
            args: args,
            env: envValues.isEmpty ? nil : envValues
        )

        do {
            try ClaudeConfigService.shared.addServer(name: catalogServer.id, config: config)

            Task {
                await registry.loadFromClaudeConfig()
            }

            close()
        } catch {
            errorMessage = error.localizedDescription
            isAdding = false
        }
    }
}

#Preview {
    AddStdioServerView(
        catalogServer: MCPCatalogServer(
            id: "zendesk",
            name: "Zendesk",
            description: "Access help center articles, analyze tickets, and draft responses",
            transport: .stdio,
            url: nil,
            command: "uvx",
            args: ["zendesk-mcp-server"],
            env: ["ZENDESK_SUBDOMAIN", "ZENDESK_EMAIL", "ZENDESK_API_KEY"],
            setupUrl: "https://github.com/reminia/zendesk-mcp-server",
            documentationUrl: nil,
            githubUrl: "https://github.com/reminia/zendesk-mcp-server",
            requirements: nil,
            installCommand: nil,
            auth: .apiKey,
            alternatives: nil
        )
    )
    .environmentObject(ServerRegistry.shared)
}
