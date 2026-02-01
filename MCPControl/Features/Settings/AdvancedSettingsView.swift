//
//  AdvancedSettingsView.swift
//  MCP Control
//
//  Advanced settings tab
//

import SwiftUI
import AppKit

struct AdvancedSettingsView: View {
    @EnvironmentObject var registry: ServerRegistry

    @AppStorage("debugLoggingEnabled") private var debugLoggingEnabled = false

    @State private var showingResetConfirmation = false

    var body: some View {
        Form {
            Section("App Info") {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                }

                LabeledContent("Build") {
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                }

                Toggle("Enable debug logging", isOn: $debugLoggingEnabled)
            }

            Section("File Locations") {
                LabeledContent("Claude Code Config") {
                    Button(action: openClaudeCodeConfig) {
                        Text("~/.claude.json")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                }

                LabeledContent("App Data") {
                    Button(action: openAppDataFolder) {
                        Text("~/Library/Application Support/MCP Control")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                }
            }

            Section("Debug") {
                LabeledContent("Config exists") {
                    Text(ClaudeConfigService.shared.configExists ? "Yes" : "No")
                }

                LabeledContent("Servers loaded") {
                    Text("\(registry.servers.count)")
                }

                Button("Reload servers") {
                    Task {
                        await registry.loadFromClaudeConfig()
                    }
                }
            }

            Section("Danger Zone") {
                Button("Reset Settings", role: .destructive) {
                    showingResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Reset Settings", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("This will reset all app settings to their default values. Your MCP servers in ~/.claude.json will not be affected.")
        }
    }

    private func openAppDataFolder() {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MCP Control")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        NSWorkspace.shared.open(url)
    }

    private func openClaudeCodeConfig() {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func resetToDefaults() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }
}

#Preview {
    AdvancedSettingsView()
        .environmentObject(ServerRegistry.shared)
}
