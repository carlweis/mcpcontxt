//
//  GeneralSettingsView.swift
//  MCP Control
//
//  General settings tab
//

import SwiftUI
import ServiceManagement
import AppKit

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInDock") private var showInDock = false

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch MCP Control at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                Toggle("Show icon in Dock", isOn: $showInDock)
                    .onChange(of: showInDock) { _, newValue in
                        setShowInDock(newValue)
                    }
            }

            Section("About MCP Control") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MCP Control makes it easy to add MCP servers to Claude Code.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Servers are saved to ~/.claude.json and are automatically available in Claude Code CLI.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("About Claude Desktop") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude Desktop uses \"Connectors\" for integrations like Slack, Linear, Figma, etc.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Connectors are managed in Claude Desktop > Settings > Connectors")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Note: Connectors are different from MCP servers and cannot be managed by this app.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Handle error - revert toggle
            launchAtLogin = !enabled
        }
    }

    private func setShowInDock(_ show: Bool) {
        if show {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

#Preview {
    GeneralSettingsView()
}
