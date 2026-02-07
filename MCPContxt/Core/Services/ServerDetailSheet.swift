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

        var isOAuth: Bool {
            switch self {
            case .installed(let server):
                return MCPCatalogService.shared.servers.first(where: { $0.id == server.name })?.isOAuth ?? false
            case .catalog(let server):
                return server.isOAuth
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
    @State private var isTesting: Bool = false
    @State private var testResult: ConnectionTestResult?
    
    init(mode: Mode, onDismiss: (() -> Void)? = nil) {
        self.mode = mode
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Two-column content (NO ScrollView)
            HStack(alignment: .top, spacing: 0) {
                // Left column
                leftColumn
                    .frame(maxWidth: .infinity)
                
                Divider()
                
                // Right column
                rightColumn
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            
            // Footer with actions
            footer
        }
        .frame(width: 650, height: 550)
        .onAppear {
            checkIfInstalled()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            // Server icon
            ServerIconView(
                serverId: mode.serverId,
                serverURL: mode.serverURL,
                serverType: mode.serverType,
                size: 48
            )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(mode.serverName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    // Type badge
                    Text(mode.serverType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badgeColor.opacity(0.2))
                        .foregroundColor(badgeColor)
                        .cornerRadius(6)

                    // OAuth badge
                    if mode.isOAuth {
                        Text("OAuth")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundColor(.secondary)
                            .cornerRadius(6)
                    }

                    // Installed badge
                    if isInstalled {
                        Label("Installed", systemImage: "checkmark.circle.fill")
                            .font(.caption)
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
    
    // MARK: - Left Column
    
    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            if case .catalog(let server) = mode {
                // OAuth warning for catalog servers
                if server.isOAuth {
                    catalogAuthSection(server: server)
                }

                // Alternatives section
                if let alternatives = server.alternatives, !alternatives.isEmpty {
                    alternativesSection(alternatives: alternatives)
                }

                // Installation & Setup section
                installationSection(server: server)

                // Documentation links - only show if there are actual docs
                if server.documentationUrl != nil || server.githubUrl != nil ||
                   (server.setupUrl != nil && server.documentationUrl == nil && server.githubUrl == nil) {
                    documentationSection(server: server)
                }
            } else if case .installed(let server) = mode {
                // For installed servers, check catalog for OAuth info
                if let catalogServer = MCPCatalogService.shared.servers.first(where: { $0.id == server.name }) {
                    if catalogServer.isOAuth {
                        catalogAuthSection(server: catalogServer)
                    }

                    if let alternatives = catalogServer.alternatives, !alternatives.isEmpty {
                        alternativesSection(alternatives: alternatives)
                    }

                    if catalogServer.documentationUrl != nil || catalogServer.githubUrl != nil ||
                       (catalogServer.setupUrl != nil && catalogServer.documentationUrl == nil && catalogServer.githubUrl == nil) {
                        documentationSection(server: catalogServer)
                    }
                }

                // Authentication info
                authSection
            }

            Spacer()
        }
        .padding()
    }
    
    private func installationSection(server: MCPCatalogServer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Installation & Setup")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                // Setup URL
                if let setupUrl = server.setupUrl {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Setup Guide", systemImage: "book")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Button(action: {
                            openURL(setupUrl)
                        }) {
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
                
                // Requirements
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
                
                // Full install command (combined for stdio servers)
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
                                Button(action: {
                                    copyToClipboard(installCommand)
                                }) {
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
                                
                                Button(action: {
                                    openInTerminal(installCommand)
                                }) {
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
                
                // Environment variables
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
                                    
                                    Button(action: {
                                        copyToClipboard(envVar)
                                    }) {
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
                // Only show links that actually exist - don't make them up!
                if let docUrl = server.documentationUrl {
                    linkButton(title: "Documentation", url: docUrl, icon: "doc.text")
                }
                
                if let githubUrl = server.githubUrl {
                    linkButton(title: "GitHub Repository", url: githubUrl, icon: "arrow.up.forward.square")
                }
                
                // Setup URL can also go here if no other docs exist
                if server.documentationUrl == nil && server.githubUrl == nil,
                   let setupUrl = server.setupUrl {
                    linkButton(title: "Setup Guide", url: setupUrl, icon: "book")
                }
            }
        }
    }
    
    private func linkButton(title: String, url: String, icon: String) -> some View {
        Button(action: {
            openURL(url)
        }) {
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
    
    private var authSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Authentication")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                if mode.serverType == .http || mode.serverType == .sse {
                    Text("Authentication happens automatically in Claude Code. When you first use this server, Claude Code will open your browser to complete the OAuth flow.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("This stdio server runs locally and may require environment variables for authentication (like API tokens).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
        }
    }

    private func catalogAuthSection(server: MCPCatalogServer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Authentication", systemImage: "person.badge.key")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("This server uses OAuth. Claude Code will open your browser to authenticate when you first connect.")
                .font(.caption)
                .foregroundColor(.secondary)

            if let alts = server.alternatives, !alts.isEmpty {
                Text("A stdio alternative is also available below if you prefer token-based auth.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
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
                            Button(action: {
                                copyToClipboard(fullCmd)
                            }) {
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
    
    // MARK: - Right Column
    
    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status section (for installed servers)
            if case .installed(let server) = mode {
                statusSection(server: server)
            }
            
            // Configuration section
            configurationSection
            
            Spacer()
        }
        .padding()
    }
    
    private func statusSection(server: MCPServer) -> some View {
        let status = statusChecker.status(for: server.name)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Connection Status")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    testServerConnection(server)
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
                .controlSize(.small)
                .disabled(isTesting)
            }

            HStack(spacing: 12) {
                // Status icon
                Group {
                    if let result = testResult {
                        switch result {
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        case .authRequired:
                            Image(systemName: "lock.circle.fill")
                                .foregroundColor(.orange)
                        case .unreachable:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        case .invalidURL:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    } else {
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
                }
                .font(.title2)

                // Status text
                VStack(alignment: .leading, spacing: 4) {
                    if let result = testResult {
                        Text(testResultTitle(result))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(testResultDescription(result))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    } else {
                        Text(statusTitle(for: status))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(statusDescription(for: status))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }

                Spacer()
            }
            .padding()
            .background(testResult != nil ? testResultBackground(testResult!) : statusBackgroundColor(for: status))
            .cornerRadius(8)
        }
    }
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 10) {
                switch mode {
                case .installed(let server):
                    installedConfiguration(server: server)
                case .catalog(let server):
                    catalogConfiguration(server: server)
                }
            }
            .padding()
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
                    
                    // Show empty state if no configuration
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
                    
                    // Show empty state if no configuration
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
                // For stdio servers, show the combined command (command + args)
                if let command = server.command {
                    let args = server.args ?? []
                    let fullCommand = args.isEmpty ? command : "\(command) \(args.joined(separator: " "))"
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Command to Run")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Text("Paste this into your terminal:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
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
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack(spacing: 12) {
            // Left side actions
            if case .installed = mode {
                Button(role: .destructive) {
                    showingRemoveConfirmation = true
                } label: {
                    Label("Remove Server", systemImage: "trash")
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
            } else if case .catalog(let server) = mode {
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
            
            // Right side - open setup URL
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
            return MCPCatalogService.shared.servers.first(where: { $0.id == server.name })?.setupUrl
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
    
    private func statusDescription(for status: MCPConnectionStatus) -> String {
        switch status {
        case .connected:
            return "This server is connected and ready to use."
        case .needsAuth:
            return "Open Claude Code and use this server to complete authentication."
        case .failed:
            return "Unable to connect. Check the configuration."
        case .unknown:
            return "Connection status not yet checked."
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

    // MARK: - Connection Test

    private func testServerConnection(_ server: MCPServer) {
        isTesting = true
        testResult = nil

        Task {
            let result: ConnectionTestResult
            switch server.type {
            case .http, .sse:
                let url = server.configuration.url ?? ""
                result = await ConnectionTester.test(url: url, headers: server.configuration.headers)
            case .stdio:
                let command = server.configuration.command ?? ""
                result = await ConnectionTester.testCommand(command)
            }

            await MainActor.run {
                testResult = result
                isTesting = false
            }
        }
    }

    private func testResultTitle(_ result: ConnectionTestResult) -> String {
        switch result {
        case .success: return "Reachable"
        case .authRequired: return "Auth Required"
        case .unreachable: return "Unreachable"
        case .invalidURL: return "Invalid URL"
        }
    }

    private func testResultDescription(_ result: ConnectionTestResult) -> String {
        switch result {
        case .success:
            return "Server responded successfully."
        case .authRequired:
            return "Server is reachable but requires authentication."
        case .unreachable(let reason):
            return reason
        case .invalidURL:
            return "The server URL is not valid."
        }
    }

    private func testResultBackground(_ result: ConnectionTestResult) -> Color {
        switch result {
        case .success: return Color.green.opacity(0.1)
        case .authRequired: return Color.orange.opacity(0.1)
        case .unreachable, .invalidURL: return Color.red.opacity(0.1)
        }
    }
    
    private func installServer(_ server: MCPCatalogServer) {
        do {
            let config = MCPServerConfig(
                type: server.transport == .sse ? "sse" : "http",
                url: server.url
            )
            try ClaudeConfigService.shared.addServer(name: server.id, config: config)
            
            // Reload registry
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
        // Create an AppleScript to open Terminal and paste the command
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
        alternatives: [CatalogAlternative(name: "GitHub (stdio)", transport: "stdio", command: "npx", args: ["-y", "@modelcontextprotocol/server-github"], env: ["GITHUB_PERSONAL_ACCESS_TOKEN"], url: nil, setupUrl: nil, notes: "Uses Personal Access Token — works without OAuth")]
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
