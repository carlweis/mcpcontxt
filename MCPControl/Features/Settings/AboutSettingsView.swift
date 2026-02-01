//
//  AboutSettingsView.swift
//  MCPControl
//
//  About tab in settings showing app info and branding
//

import SwiftUI

struct AboutSettingsView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon and name
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)

                Text("MCP Control")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Description
            Text("A menu bar app for managing MCP servers\nfor Claude Code CLI")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 200)

            // Branding
            VStack(spacing: 8) {
                Text("Built by")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: openOpcodezero) {
                    HStack(spacing: 6) {
                        Text("opcodezero")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.link)
            }

            // Links
            HStack(spacing: 20) {
                Button("Website") {
                    openURL("https://opcodezero.com")
                }
                .buttonStyle(.link)

                Button("GitHub") {
                    openURL("https://github.com/opcodezerohq/mcp-control")
                }
                .buttonStyle(.link)

                Button("Report Issue") {
                    openURL("https://github.com/opcodezerohq/mcp-control/issues")
                }
                .buttonStyle(.link)
            }
            .font(.caption)

            Spacer()

            // Copyright
            Text("© 2026 opcodezero LLC. All rights reserved.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openOpcodezero() {
        openURL("https://opcodezero.com")
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    AboutSettingsView()
        .frame(width: 550, height: 400)
}
