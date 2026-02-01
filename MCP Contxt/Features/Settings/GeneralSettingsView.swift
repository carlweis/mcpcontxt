//
//  GeneralSettingsView.swift
//  MCP Contxt
//
//  General settings tab
//

import SwiftUI
import ServiceManagement
import UserNotifications
import AppKit

struct GeneralSettingsView: View {
    @AppStorage("syncToClaudeDesktop") private var syncToClaudeDesktop = true
    @AppStorage("syncToClaudeCode") private var syncToClaudeCode = true
    @AppStorage("autoSyncOnChanges") private var autoSyncOnChanges = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInDock") private var showInDock = false
    @AppStorage("healthCheckInterval") private var healthCheckInterval: Double = 30
    @AppStorage("showNotificationOnFailure") private var showNotificationOnFailure = true
    @AppStorage("showNotificationOnAuthExpiry") private var showNotificationOnAuthExpiry = true

    @State private var notificationsAuthorized = false

    var body: some View {
        Form {
            Section("Sync Targets") {
                Toggle(isOn: $syncToClaudeDesktop) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claude Desktop")
                        Text(SyncTarget.claudeDesktop.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(!ConfigurationManager.shared.isClaudeDesktopAvailable)

                Toggle(isOn: $syncToClaudeCode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claude Code CLI (User Scope)")
                        Text(SyncTarget.claudeCodeUser.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Auto-sync when servers change", isOn: $autoSyncOnChanges)

                Toggle("Launch MCP Contxt at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                Toggle("Show icon in Dock", isOn: $showInDock)
                    .onChange(of: showInDock) { _, newValue in
                        setShowInDock(newValue)
                    }
            }

            Section("Health Monitoring") {
                Picker("Check interval", selection: $healthCheckInterval) {
                    ForEach(HealthCheckInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval.rawValue)
                    }
                }
                .onChange(of: healthCheckInterval) { _, newValue in
                    HealthMonitor.shared.setCheckInterval(newValue)
                }

                Toggle("Show notification on server failure", isOn: $showNotificationOnFailure)
                    .disabled(!notificationsAuthorized)

                Toggle("Show notification when auth expires", isOn: $showNotificationOnAuthExpiry)
                    .disabled(!notificationsAuthorized)

                if !notificationsAuthorized {
                    Button("Enable Notifications") {
                        Task {
                            notificationsAuthorized = await NotificationService.shared.requestAuthorization()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            checkNotificationAuthorization()
        }
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

    private func checkNotificationAuthorization() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                notificationsAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
}

#Preview {
    GeneralSettingsView()
}
