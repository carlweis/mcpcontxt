//
//  AddServerView.swift
//  MCPContxt
//
//  Add or edit an MCP server
//

import SwiftUI

struct AddServerView: View {
    @Environment(\.dismiss) private var environmentDismiss
    @EnvironmentObject var registry: ServerRegistry

    let editingServer: MCPServer?
    let onDismiss: (() -> Void)?

    @State private var name: String = ""
    @State private var serverType: MCPServerType = .http
    @State private var url: String = ""
    @State private var headers: [HeaderEntry] = []
    @State private var command: String = ""
    @State private var args: String = ""
    @State private var envVars: [EnvEntry] = []

    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    var isEditing: Bool { editingServer != nil }

    init(editingServer: MCPServer? = nil, onDismiss: (() -> Void)? = nil) {
        self.editingServer = editingServer
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

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    basicInfoSection
                    configurationSection
                    infoSection
                }
                .padding()
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 480, height: 480)
        .onAppear(perform: loadEditingServer)
    }

    private var header: some View {
        HStack {
            Text(isEditing ? "Edit Server" : "Add MCP Server")
                .font(.headline)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding()
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Information")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            LabeledContent("Name") {
                TextField("my-server", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Type") {
                Picker("", selection: $serverType) {
                    ForEach(MCPServerType.allCases, id: \.self) { type in
                        Text(type.description).tag(type)
                    }
                }
                .labelsHidden()
            }
        }
    }

    @ViewBuilder
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            switch serverType {
            case .http, .sse:
                httpConfiguration
            case .stdio:
                stdioConfiguration
            }
        }
    }

    private var httpConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("URL") {
                TextField("https://mcp.example.com/mcp", text: $url)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Headers")
                    Spacer()
                    Button(action: { headers.append(HeaderEntry()) }) {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }

                ForEach($headers) { $header in
                    HStack {
                        TextField("Key", text: $header.key)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)

                        TextField("Value", text: $header.value)
                            .textFieldStyle(.roundedBorder)

                        Button(action: { headers.removeAll { $0.id == header.id } }) {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var stdioConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Command") {
                TextField("npx", text: $command)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Arguments") {
                TextField("-y @modelcontextprotocol/server-github", text: $args)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Environment Variables")
                    Spacer()
                    Button(action: { envVars.append(EnvEntry()) }) {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }

                ForEach($envVars) { $env in
                    HStack {
                        TextField("Key", text: $env.key)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)

                        SecureField("Value", text: $env.value)
                            .textFieldStyle(.roundedBorder)

                        Button(action: { envVars.removeAll { $0.id == env.id } }) {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Server will be saved to ~/.claude.json for use with Claude Code")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack {
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(isEditing ? "Save" : "Add Server") {
                save()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving || !isValid)
        }
        .padding()
    }

    private var isValid: Bool {
        guard !name.isEmpty else { return false }

        switch serverType {
        case .http, .sse:
            return !url.isEmpty && URL(string: url) != nil
        case .stdio:
            return !command.isEmpty
        }
    }

    private func loadEditingServer() {
        guard let server = editingServer else { return }

        name = server.name
        serverType = server.type

        switch server.type {
        case .http, .sse:
            url = server.configuration.url ?? ""
            headers = server.configuration.headers?.map { HeaderEntry(key: $0.key, value: $0.value) } ?? []
        case .stdio:
            command = server.configuration.command ?? ""
            args = server.configuration.args?.joined(separator: " ") ?? ""
            envVars = server.configuration.env?.map { EnvEntry(key: $0.key, value: $0.value) } ?? []
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil

        do {
            let config = buildConfig()
            try ClaudeConfigService.shared.addServer(name: name, config: config)

            // Reload registry
            Task {
                await registry.loadFromClaudeConfig()
                await MainActor.run {
                    dismiss()
                }
            }
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }

    private func buildConfig() -> MCPServerConfig {
        switch serverType {
        case .http, .sse:
            let headersDict = headers.isEmpty ? nil : Dictionary(uniqueKeysWithValues: headers.map { ($0.key, $0.value) })
            return MCPServerConfig(
                type: serverType == .sse ? "sse" : "http",
                url: url,
                headers: headersDict
            )
        case .stdio:
            let argsArray = args.isEmpty ? nil : args.components(separatedBy: " ").filter { !$0.isEmpty }
            let envDict = envVars.isEmpty ? nil : Dictionary(uniqueKeysWithValues: envVars.map { ($0.key, $0.value) })
            return MCPServerConfig(
                type: "stdio",
                command: command,
                args: argsArray,
                env: envDict
            )
        }
    }
}

// MARK: - Helper Types

struct HeaderEntry: Identifiable {
    let id = UUID()
    var key: String = ""
    var value: String = ""
}

struct EnvEntry: Identifiable {
    let id = UUID()
    var key: String = ""
    var value: String = ""
}

#Preview {
    AddServerView()
        .environmentObject(ServerRegistry.shared)
}
