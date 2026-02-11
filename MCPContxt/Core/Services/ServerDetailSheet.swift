//
//  ServerDetailSheet.swift
//  MCPContxt
//
//  Unified detail view for both installed and catalog MCP servers
//

import SwiftUI
import AppKit

struct ServerDetailSheet: View {
    enum Mode {
        case installed(MCPServer)
        case catalog(MCPCatalogServer)

        var serverId: String {
            switch self {
            case .installed(let server): return server.name
            case .catalog(let server): return server.id
            }
        }

        var serverName: String {
            switch self {
            case .installed(let server): return server.name
            case .catalog(let server): return server.name
            }
        }

        var serverType: MCPServerType {
            switch self {
            case .installed(let server): return server.type
            case .catalog(let server):
                return server.transport == .sse ? .sse :
                       server.transport == .stdio ? .stdio : .http
            }
        }

        var serverURL: String? {
            switch self {
            case .installed(let server): return server.configuration.url
            case .catalog(let server): return server.url
            }
        }

        var description: String {
            switch self {
            case .installed: return "Configured in ~/.claude.json"
            case .catalog(let server): return server.description
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var registry: ServerRegistry
    @ObservedObject private var statusChecker = MCPStatusChecker.shared

    let mode: Mode
    let onDismiss: (() -> Void)?

    @State private var isInstalled: Bool = false
    @State private var showingRemoveConfirmation = false

    init(mode: Mode, onDismiss: (() -> Void)? = nil) {
        self.mode = mode
        self.onDismiss = onDismiss
    }

    /// Look up catalog data for the current server
    private var catalogServer: MCPCatalogServer? {
        switch mode {
        case .installed(let server):
            return MCPCatalog.server(withId: server.name)
        case .catalog(let server):
            return server
        }
    }

    var body: some View {
        switch mode {
        case .installed:
            installedBody
        case .catalog:
            catalogBody
        }
    }

    // MARK: - Installed Server Layout

    private var installedBody: some View {
        VStack(spacing: 0) {
            header
            Divider()

            VStack(alignment: .leading, spacing: 14) {
                statusRow

                Divider()

                configurationSection

                if let cat = catalogServer, hasLinks(cat) {
                    Divider()
                    linksSection(cat)
                }

                Divider()

                removeButton
            }
            .padding()
        }
        .frame(width: 450)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { checkIfInstalled() }
    }

    // MARK: - Catalog Server Layout

    private var catalogBody: some View {
        VStack(spacing: 0) {
            header
            Divider()

            VStack(alignment: .leading, spacing: 16) {
                if case .catalog(let server) = mode {
                    if let alternatives = server.alternatives, !alternatives.isEmpty {
                        alternativesSection(alternatives: alternatives)
                    }

                    installationSection(server: server)

                    if server.documentationUrl != nil || server.githubUrl != nil ||
                       (server.setupUrl != nil && server.documentationUrl == nil && server.githubUrl == nil) {
                        documentationSection(server: server)
                    }
                }

                Spacer()
            }
            .padding()

            Divider()
            catalogFooter
        }
        .frame(width: 550, height: 500)
        .onAppear { checkIfInstalled() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ServerIconView(
                serverId: mode.serverId,
                serverURL: mode.serverURL,
                serverType: mode.serverType,
                size: 40
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(mode.serverName)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(mode.serverType.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor.opacity(0.2))
                        .foregroundColor(badgeColor)
                        .cornerRadius(4)

                    if let cat = catalogServer, cat.official {
                        Label("Official", systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }

                    if isInstalled, case .catalog = mode {
                        Label("Installed", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }

                Text(mode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Done") {
                dismissSheet()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var badgeColor: Color {
        switch mode.serverType {
        case .http, .sse: return .blue
        case .stdio: return .purple
        }
    }

    // MARK: - Status Row (Installed)

    private var statusRow: some View {
        let status: MCPConnectionStatus = {
            if case .installed(let server) = mode {
                return statusChecker.status(for: server.name)
            }
            return .unknown
        }()

        return HStack(spacing: 10) {
            statusIcon(for: status)
                .font(.body)

            Text(statusTitle(for: status))
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            if status == .needsAuth {
                Button {
                    openInTerminal("claude mcp")
                } label: {
                    Label("Authenticate", systemImage: "terminal")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.orange)
            }
        }
        .padding(10)
        .background(statusBackgroundColor(for: status))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func statusIcon(for status: MCPConnectionStatus) -> some View {
        switch status {
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .needsAuth:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .unknown:
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.gray)
        }
    }

    // MARK: - Configuration Section (Installed)

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Configuration")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                if case .installed(let server) = mode {
                    installedConfiguration(server: server)
                } else if case .catalog(let server) = mode {
                    catalogConfiguration(server: server)
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
        }
    }

    private func installedConfiguration(server: MCPServer) -> some View {
        Group {
            switch server.type {
            case .http, .sse:
                VStack(alignment: .leading, spacing: 10) {
                    if let url = server.configuration.url {
                        configRow("URL", value: url)
                    }

                    if let headers = server.configuration.headers, !headers.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Headers:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(Array(headers.keys.sorted()), id: \.self) { key in
                                HStack {
                                    Text("\(key): ")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Text(headers[key] ?? "")
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }

                    if server.configuration.url == nil && (server.configuration.headers?.isEmpty ?? true) {
                        Text("No configuration available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

            case .stdio:
                VStack(alignment: .leading, spacing: 10) {
                    if let command = server.configuration.command {
                        configRow("Command", value: command)
                    }

                    if let args = server.configuration.args, !args.isEmpty {
                        configRow("Arguments", value: args.joined(separator: " "))
                    }

                    if let env = server.configuration.env, !env.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Environment Variables:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(Array(env.keys.sorted()), id: \.self) { key in
                                HStack {
                                    Text(key)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                    Spacer()
                                    Text("***")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    if server.configuration.command == nil {
                        Text("No configuration available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func catalogConfiguration(server: MCPCatalogServer) -> some View {
        Group {
            if server.isRemote {
                if let url = server.url {
                    configRow("URL", value: url)
                } else {
                    Text("No URL configured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                if let command = server.command {
                    let args = server.args ?? []
                    let fullCommand = args.isEmpty ? command : "\(command) \(args.joined(separator: " "))"

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Command")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)

                        HStack(spacing: 8) {
                            Text(fullCommand)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(3)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(4)

                            VStack(spacing: 4) {
                                Button(action: {
                                    copyToClipboard(fullCommand)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .help("Copy")

                                Button(action: {
                                    openInTerminal(fullCommand)
                                }) {
                                    Image(systemName: "terminal")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                                .help("Run in Terminal")
                            }
                        }
                    }
                } else {
                    Text("No command configured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func configRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)

            HStack {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)

                Spacer()

                Button(action: {
                    copyToClipboard(value)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }
        }
    }

    // MARK: - Links Section (Installed)

    private func hasLinks(_ server: MCPCatalogServer) -> Bool {
        server.setupUrl != nil || server.documentationUrl != nil || server.githubUrl != nil
    }

    private func linksSection(_ server: MCPCatalogServer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Links")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                if let setupUrl = server.setupUrl {
                    linkPill(title: "Setup Guide", icon: "book", url: setupUrl)
                }
                if let docUrl = server.documentationUrl {
                    linkPill(title: "Docs", icon: "doc.text", url: docUrl)
                }
                if let githubUrl = server.githubUrl {
                    linkPill(title: "GitHub", icon: "arrow.up.forward.square", url: githubUrl)
                }
            }
        }
    }

    private func linkPill(title: String, icon: String, url: String) -> some View {
        Button(action: { openURL(url) }) {
            Label(title, systemImage: icon)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Remove Button (Installed)

    private var removeButton: some View {
        HStack {
            Button(role: .destructive) {
                showingRemoveConfirmation = true
            } label: {
                Label("Remove Server", systemImage: "trash")
                    .font(.caption)
            }
            .confirmationDialog(
                "Remove this server from Claude configuration?",
                isPresented: $showingRemoveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    removeServer()
                }
                Button("Cancel", role: .cancel) {}
            }

            Spacer()
        }
    }

    // MARK: - Catalog Mode Sections

    private func installationSection(server: MCPCatalogServer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Installation & Setup")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 12) {
                if let setupUrl = server.setupUrl {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Setup Guide", systemImage: "book")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Button(action: { openURL(setupUrl) }) {
                            HStack {
                                Text(setupUrl)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                }

                if let requirements = server.requirements, !requirements.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Requirements", systemImage: "checkmark.circle")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(requirements, id: \.self) { requirement in
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 4))
                                        .foregroundColor(.secondary)
                                    Text(requirement)
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                    }
                }

                if let installCommand = server.installCommand {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Install Command", systemImage: "terminal")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Copy and paste this into your terminal:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Text(installCommand)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(3)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(4)

                            VStack(spacing: 4) {
                                Button(action: { copyToClipboard(installCommand) }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption)
                                        Text("Copy")
                                            .font(.caption2)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Copy to clipboard")

                                Button(action: { openInTerminal(installCommand) }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "terminal")
                                            .font(.caption)
                                        Text("Run")
                                            .font(.caption2)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .help("Open Terminal and paste command")
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                    }
                }

                if let envVars = server.env, !envVars.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Required Environment Variables", systemImage: "key")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)

                        Text("You'll need to set these before running:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(envVars, id: \.self) { envVar in
                                HStack {
                                    Text(envVar)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)

                                    Spacer()

                                    Button(action: { copyToClipboard(envVar) }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }

    private func documentationSection(server: MCPCatalogServer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Documentation")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                if let docUrl = server.documentationUrl {
                    catalogLinkButton(title: "Documentation", url: docUrl, icon: "doc.text")
                }
                if let githubUrl = server.githubUrl {
                    catalogLinkButton(title: "GitHub Repository", url: githubUrl, icon: "arrow.up.forward.square")
                }
                if server.documentationUrl == nil && server.githubUrl == nil,
                   let setupUrl = server.setupUrl {
                    catalogLinkButton(title: "Setup Guide", url: setupUrl, icon: "book")
                }
            }
        }
    }

    private func catalogLinkButton(title: String, url: String, icon: String) -> some View {
        Button(action: { openURL(url) }) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(title)
                    .font(.caption)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func alternativesSection(alternatives: [CatalogAlternative]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alternatives")
                .font(.headline)
                .foregroundColor(.primary)

            ForEach(alternatives) { alt in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: alt.isStdio ? "terminal" : "globe")
                            .font(.title3)
                            .foregroundColor(alt.isStdio ? .purple : .blue)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(alt.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text(alt.transport.uppercased())
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(alt.isStdio ? Color.purple.opacity(0.2) : Color.secondary.opacity(0.2))
                                    .cornerRadius(3)
                            }

                            if let notes = alt.notes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if alt.isStdio, let command = alt.command {
                            let args = alt.args ?? []
                            let fullCmd = args.isEmpty ? command : "\(command) \(args.joined(separator: " "))"
                            Button(action: { copyToClipboard(fullCmd) }) {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.caption2)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .help("Copy command: \(fullCmd)")
                        }
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Catalog Footer

    private var catalogFooter: some View {
        HStack(spacing: 12) {
            if case .catalog(let server) = mode {
                if !isInstalled {
                    if server.isStdio {
                        Button {
                            configureStdioServer(server)
                        } label: {
                            Label("Configure Server", systemImage: "gearshape")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            installServer(server)
                        } label: {
                            Label("Install Server", systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Spacer()

            if let setupUrl = getSetupUrl() {
                Button {
                    openURL(setupUrl)
                } label: {
                    Label("Open Setup Guide", systemImage: "safari")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Helper Functions

    private func checkIfInstalled() {
        isInstalled = registry.server(withName: mode.serverId) != nil
    }

    private func getSetupUrl() -> String? {
        switch mode {
        case .catalog(let server):
            return server.setupUrl
        case .installed(let server):
            return MCPCatalog.server(withId: server.name)?.setupUrl
        }
    }

    private func statusTitle(for status: MCPConnectionStatus) -> String {
        switch status {
        case .connected: return "Connected"
        case .needsAuth: return "Needs Authentication"
        case .failed: return "Connection Failed"
        case .unknown: return "Status Unknown"
        }
    }

    private func statusBackgroundColor(for status: MCPConnectionStatus) -> Color {
        switch status {
        case .connected: return Color.green.opacity(0.1)
        case .needsAuth: return Color.orange.opacity(0.1)
        case .failed: return Color.red.opacity(0.1)
        case .unknown: return Color.secondary.opacity(0.05)
        }
    }

    private func installServer(_ server: MCPCatalogServer) {
        do {
            let config = MCPServerConfig(
                type: server.transport == .sse ? "sse" : "http",
                url: server.url
            )
            try ClaudeConfigService.shared.addServer(name: server.id, config: config)

            Task {
                await registry.loadFromClaudeConfig()
                await MainActor.run {
                    isInstalled = true
                }
            }
        } catch {
            print("[ServerDetailSheet] Failed to install server: \(error)")
        }
    }

    private func configureStdioServer(_ server: MCPCatalogServer) {
        NotificationCenter.default.post(name: .openStdioServerConfig, object: server)
        dismissSheet()
    }

    private func removeServer() {
        guard case .installed(let server) = mode else { return }

        Task {
            do {
                try await registry.remove(server)
                await MainActor.run {
                    NotificationCenter.default.post(name: .serverRemoved, object: server.name)
                    dismissSheet()
                }
            } catch {
                print("[ServerDetailSheet] Failed to remove server: \(error)")
            }
        }
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func openInTerminal(_ command: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "\(command.replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)

            if let error = error {
                print("[ServerDetailSheet] Failed to open Terminal: \(error)")
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func dismissSheet() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("Catalog Server") {
    let server = MCPCatalogServer(
        id: "github",
        name: "GitHub MCP",
        description: "Access GitHub repositories, issues, and pull requests",
        transport: .http,
        url: "https://api.githubcopilot.com/mcp/",
        command: nil,
        args: nil,
        env: nil,
        setupUrl: "https://github.com/modelcontextprotocol/servers",
        documentationUrl: "https://modelcontextprotocol.io/docs",
        githubUrl: "https://github.com/modelcontextprotocol/servers",
        requirements: ["Node.js 18+", "GitHub Account"],
        installCommand: "npm install -g @modelcontextprotocol/server-github",
        auth: .oauth,
        alternatives: [CatalogAlternative(name: "GitHub (stdio)", transport: "stdio", command: "npx", args: ["-y", "@modelcontextprotocol/server-github"], env: ["GITHUB_PERSONAL_ACCESS_TOKEN"], url: nil, setupUrl: nil, notes: "Uses Personal Access Token — works without OAuth")],
        official: true
    )

    return ServerDetailSheet(mode: .catalog(server))
        .environmentObject(ServerRegistry.shared)
}

#Preview("Installed Server") {
    let server = MCPServer(
        name: "slack",
        type: .http,
        configuration: .http(url: "https://mcp.slack.com/mcp")
    )

    return ServerDetailSheet(mode: .installed(server))
        .environmentObject(ServerRegistry.shared)
}
