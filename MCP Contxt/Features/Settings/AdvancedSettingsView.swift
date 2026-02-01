//
//  AdvancedSettingsView.swift
//  MCP Contxt
//
//  Advanced settings tab
//

import SwiftUI
import AppKit

struct AdvancedSettingsView: View {
    @EnvironmentObject var registry: ServerRegistry

    @AppStorage("debugLoggingEnabled") private var debugLoggingEnabled = false

    @State private var showingResetConfirmation = false
    @State private var showingClearDataConfirmation = false
    @State private var claudeDesktopVersion: String?
    @State private var isClaudeDesktopInstalled = false

    var body: some View {
        Form {
            Section("Debugging") {
                Toggle("Enable debug logging", isOn: $debugLoggingEnabled)

                LabeledContent("App Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                }

                LabeledContent("Build") {
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                }
            }

            Section("Claude Desktop") {
                if isClaudeDesktopInstalled {
                    LabeledContent("Version") {
                        Text(claudeDesktopVersion ?? "Unknown")
                    }

                    LabeledContent("Status") {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(ProcessMonitor.shared.isClaudeDesktopRunning ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(ProcessMonitor.shared.isClaudeDesktopRunning ? "Running" : "Not Running")
                        }
                    }

                    Button("Restart Claude Desktop") {
                        Task {
                            _ = await ProcessMonitor.shared.restartClaudeDesktop()
                        }
                    }
                } else {
                    Text("Claude Desktop is not installed")
                        .foregroundColor(.secondary)
                }
            }

            Section("File Locations") {
                LabeledContent("App Data") {
                    Button(action: openAppDataFolder) {
                        Text("~/Library/Application Support/MCP Contxt")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                }

                LabeledContent("Claude Desktop Config") {
                    Button(action: openClaudeDesktopConfig) {
                        Text(SyncTarget.claudeDesktop.description)
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                }

                LabeledContent("Claude Code Config") {
                    Button(action: openClaudeCodeConfig) {
                        Text(SyncTarget.claudeCodeUser.description)
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                }

                LabeledContent("Claude Logs") {
                    Button(action: openClaudeLogs) {
                        Text("~/Library/Logs/Claude")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                }
            }

            Section("Danger Zone") {
                Button("Reset to Defaults") {
                    showingResetConfirmation = true
                }

                Button("Clear All Data", role: .destructive) {
                    showingClearDataConfirmation = true
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear(perform: loadClaudeDesktopInfo)
        .alert("Reset to Defaults", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values. Your servers will not be affected.")
        }
        .alert("Clear All Data", isPresented: $showingClearDataConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will remove all servers and settings from MCP Contxt. This will NOT affect your Claude Desktop or Claude Code configurations.")
        }
    }

    private func loadClaudeDesktopInfo() {
        isClaudeDesktopInstalled = ProcessMonitor.shared.isClaudeDesktopInstalled
        claudeDesktopVersion = ProcessMonitor.shared.claudeDesktopVersion
    }

    private func openAppDataFolder() {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MCP Contxt")
        NSWorkspace.shared.open(url)
    }

    private func openClaudeDesktopConfig() {
        let url = SyncTarget.claudeDesktop.configPath
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openClaudeCodeConfig() {
        let url = SyncTarget.claudeCodeUser.configPath
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openClaudeLogs() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("Claude")
        NSWorkspace.shared.open(url)
    }

    private func resetToDefaults() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }

    private func clearAllData() {
        // Remove all servers
        Task {
            for server in registry.servers where server.source != .enterprise {
                try? await registry.remove(server)
            }
        }

        // Reset settings
        resetToDefaults()
    }
}

#Preview {
    AdvancedSettingsView()
        .environmentObject(ServerRegistry.shared)
}
