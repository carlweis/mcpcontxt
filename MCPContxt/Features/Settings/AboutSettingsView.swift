//
//  AboutSettingsView.swift
//  MCPContxt
//
//  About tab in settings showing app info and branding
//

import SwiftUI

struct AboutSettingsView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // App icon and name
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text("MCP Contxt")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Description
            Text("Browse, install, and manage MCP servers\nfor Claude Code")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 200)

            // Links
            HStack(spacing: 24) {
                Button(action: { openURL("https://mcpcontxt.com") }) {
                    Label("Website", systemImage: "globe")
                }
                .buttonStyle(.link)

                Button(action: { openURL("https://github.com/opcodezerohq/mcpcontxt") }) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .buttonStyle(.link)

                Button(action: { openURL("https://github.com/opcodezerohq/mcpcontxt/issues") }) {
                    Label("Report Issue", systemImage: "exclamationmark.bubble")
                }
                .buttonStyle(.link)
            }
            .font(.callout)

            Spacer()

            // Open source notice
            VStack(spacing: 4) {
                Text("Free & Open Source")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("MIT License")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
