//
//  AddServerView.swift
//  MCPContxt
//
//  Add or edit an MCP server
//

import SwiftUI

enum AuthPreset: String, CaseIterable {
    case none = "No Auth"
    case bearerToken = "Bearer Token"
    case apiKey = "API Key"
    case basicAuth = "Basic Auth"
    case custom = "Custom Headers"
}

struct AddServerView: View {
    @Environment(\.dismiss) private var environmentDismiss
    @EnvironmentObject var registry: ServerRegistry

    let editingServer: MCPServer?
    let onDismiss: (() -> Void)?

    @State private var name: String = ""
    @State private var serverType: MCPServerType = .http
    @State private var url: String = ""

    // Auth preset state
    @State private var authPreset: AuthPreset = .none
    @State private var bearerToken: String = ""
    @State private var apiKeyName: String = "X-API-Key"
    @State private var apiKeyValue: String = ""
    @State private var basicUsername: String = ""
    @State private var basicPassword: String = ""
    @State private var customHeaders: [HeaderEntry] = []

    @State private var command: String = ""
    @State private var args: String = ""
    @State private var envVars: [EnvEntry] = []

    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var isTesting: Bool = false
    @State private var testResult: ConnectionTestResult?

    private let commonApiKeyNames = [
        "X-API-Key",
        "Authorization",
        "X-Auth-Token",
        "Api-Key",
        "X-Access-Token",
    ]

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

            // Auth preset section
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Authentication") {
                    Picker("", selection: $authPreset) {
                        ForEach(AuthPreset.allCases, id: \.self) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .labelsHidden()
                }

                switch authPreset {
                case .none:
                    EmptyView()

                case .bearerToken:
                    LabeledContent("Token") {
                        SecureField("Enter bearer token", text: $bearerToken)
                            .textFieldStyle(.roundedBorder)
                    }

                case .apiKey:
                    LabeledContent("Key Name") {
                        Picker("", selection: $apiKeyName) {
                            ForEach(commonApiKeyNames, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .labelsHidden()
                    }

                    LabeledContent("Key Value") {
                        SecureField("Enter API key", text: $apiKeyValue)
                            .textFieldStyle(.roundedBorder)
                    }

                case .basicAuth:
                    LabeledContent("Username") {
                        TextField("Username", text: $basicUsername)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("Password") {
                        SecureField("Password", text: $basicPassword)
                            .textFieldStyle(.roundedBorder)
                    }

                case .custom:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Headers")
                            Spacer()
                            Button(action: { customHeaders.append(HeaderEntry()) }) {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach($customHeaders) { $header in
                            HStack {
                                TextField("Key", text: $header.key)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)

                                TextField("Value", text: $header.value)
                                    .textFieldStyle(.roundedBorder)

                                Button(action: { customHeaders.removeAll { $0.id == header.id } }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
            } else if let result = testResult {
                testResultView(result)
            }

            Spacer()

            Button {
                testConnection()
            } label: {
                if isTesting {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else {
                    Label("Test", systemImage: "bolt.horizontal")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isTesting || !isValid)

            Button(isEditing ? "Save" : "Add Server") {
                save()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving || !isValid)
        }
        .padding()
    }

    @ViewBuilder
    private func testResultView(_ result: ConnectionTestResult) -> some View {
        switch result {
        case .success:
            Label("Reachable", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        case .authRequired:
            Label("Reachable (auth required)", systemImage: "lock.circle.fill")
                .font(.caption)
                .foregroundColor(.orange)
        case .unreachable(let reason):
            Label(reason, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(.red)
        case .invalidURL:
            Label("Invalid URL", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        errorMessage = nil

        Task {
            let result: ConnectionTestResult
            switch serverType {
            case .http, .sse:
                result = await ConnectionTester.test(url: url, headers: headersFromPreset())
            case .stdio:
                result = await ConnectionTester.testCommand(command)
            }

            await MainActor.run {
                testResult = result
                isTesting = false
            }
        }
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
            loadAuthPresetFromHeaders(server.configuration.headers)
        case .stdio:
            command = server.configuration.command ?? ""
            args = server.configuration.args?.joined(separator: " ") ?? ""
            envVars = server.configuration.env?.map { EnvEntry(key: $0.key, value: $0.value) } ?? []
        }
    }

    private func loadAuthPresetFromHeaders(_ headers: [String: String]?) {
        guard let headers = headers, !headers.isEmpty else {
            authPreset = .none
            return
        }

        // Detect Bearer Token
        if let authValue = headers["Authorization"], authValue.hasPrefix("Bearer ") {
            authPreset = .bearerToken
            bearerToken = String(authValue.dropFirst("Bearer ".count))
            return
        }

        // Detect Basic Auth
        if let authValue = headers["Authorization"], authValue.hasPrefix("Basic ") {
            authPreset = .basicAuth
            if let decoded = Data(base64Encoded: String(authValue.dropFirst("Basic ".count))),
               let decodedString = String(data: decoded, encoding: .utf8) {
                let parts = decodedString.split(separator: ":", maxSplits: 1)
                basicUsername = String(parts.first ?? "")
                basicPassword = String(parts.last ?? "")
            }
            return
        }

        // Detect API Key (single header matching common names)
        if headers.count == 1, let entry = headers.first,
           commonApiKeyNames.contains(entry.key) {
            authPreset = .apiKey
            apiKeyName = entry.key
            apiKeyValue = entry.value
            return
        }

        // Fall back to custom headers
        authPreset = .custom
        customHeaders = headers.map { HeaderEntry(key: $0.key, value: $0.value) }
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

    private func headersFromPreset() -> [String: String]? {
        switch authPreset {
        case .none:
            return nil
        case .bearerToken:
            guard !bearerToken.isEmpty else { return nil }
            return ["Authorization": "Bearer \(bearerToken)"]
        case .apiKey:
            guard !apiKeyName.isEmpty, !apiKeyValue.isEmpty else { return nil }
            return [apiKeyName: apiKeyValue]
        case .basicAuth:
            guard !basicUsername.isEmpty else { return nil }
            let encoded = Data("\(basicUsername):\(basicPassword)".utf8).base64EncodedString()
            return ["Authorization": "Basic \(encoded)"]
        case .custom:
            let filtered = customHeaders.filter { !$0.key.isEmpty }
            guard !filtered.isEmpty else { return nil }
            return Dictionary(uniqueKeysWithValues: filtered.map { ($0.key, $0.value) })
        }
    }

    private func buildConfig() -> MCPServerConfig {
        switch serverType {
        case .http, .sse:
            return MCPServerConfig(
                type: serverType == .sse ? "sse" : "http",
                url: url,
                headers: headersFromPreset()
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
