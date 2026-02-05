//
//  ServerIconView.swift
//  MCPContxt
//
//  Reusable server icon component that displays favicon or fallback SF Symbol
//

import SwiftUI

struct ServerIconView: View {
    let serverId: String
    let serverURL: String?
    let serverType: MCPServerType
    var size: CGFloat = 32

    @ObservedObject private var faviconService = FaviconService.shared
    @State private var currentIcon: NSImage?

    var body: some View {
        Group {
            if let favicon = currentIcon {
                Image(nsImage: favicon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            loadIcon()
        }
        .onChange(of: faviconService.icons[serverId]) { _, newIcon in
            currentIcon = newIcon
        }
    }

    private func loadIcon() {
        guard let url = serverURL else { return }
        // Check if already cached
        if let cached = faviconService.icons[serverId] {
            currentIcon = cached
        } else {
            // Trigger fetch (will update via onChange)
            Task {
                _ = faviconService.icon(for: url, serverId: serverId)
            }
        }
    }

    private var fallbackView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(Color.primary.opacity(0.08))

            Image(systemName: fallbackIcon)
                .font(.system(size: size * 0.5))
                .foregroundColor(.secondary)
        }
    }

    private var fallbackIcon: String {
        switch serverType {
        case .http:
            return "globe"
        case .sse:
            return "antenna.radiowaves.left.and.right"
        case .stdio:
            return "terminal"
        }
    }
}

// Convenience initializer for MCPCatalogServer
extension ServerIconView {
    init(catalogServer: MCPCatalogServer, size: CGFloat = 32) {
        self.serverId = catalogServer.id
        self.serverURL = catalogServer.url
        switch catalogServer.transport {
        case .sse:
            self.serverType = .sse
        case .stdio:
            self.serverType = .stdio
        case .http:
            self.serverType = .http
        }
        self.size = size
    }
}

#Preview {
    HStack(spacing: 16) {
        ServerIconView(
            serverId: "slack",
            serverURL: "https://mcp.slack.com/mcp",
            serverType: .http,
            size: 40
        )

        ServerIconView(
            serverId: "github",
            serverURL: "https://api.githubcopilot.com/mcp/",
            serverType: .http,
            size: 40
        )

        ServerIconView(
            serverId: "local",
            serverURL: nil,
            serverType: .stdio,
            size: 40
        )
    }
    .padding()
}
