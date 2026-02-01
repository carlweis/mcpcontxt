//
//  ServersSettingsView.swift
//  MCPControl
//
//  Servers settings tab - full server management
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ServersSettingsView: View {
    @EnvironmentObject var registry: ServerRegistry

    @State private var showingImport = false
    @State private var showingExport = false
    @State private var exportURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            ServerListView()
                .environmentObject(registry)

            Divider()

            // Import/Export toolbar
            HStack {
                Button(action: { showingImport = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

                Button(action: exportConfiguration) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                Spacer()

                if let url = exportURL {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Exported to \(url.lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingImport) {
            ImportServersView()
                .environmentObject(registry)
        }
    }

    private func exportConfiguration() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "mcp-servers.json"
        panel.title = "Export MCP Servers"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dateEncodingStrategy = .iso8601

                    let data = try encoder.encode(registry.servers)
                    try data.write(to: url)

                    exportURL = url

                    // Clear the success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        exportURL = nil
                    }
                } catch {
                    // Show error
                }
            }
        }
    }
}

#Preview {
    ServersSettingsView()
        .environmentObject(ServerRegistry.shared)
        .frame(width: 550, height: 350)
}
