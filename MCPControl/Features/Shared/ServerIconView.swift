//
//  ServerIconView.swift
//  MCPControl
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

    var body: some View {
        Group {
            if let url = serverURL,
               let favicon = faviconService.icon(for: url, serverId: serverId) {
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
    }

    private var fallbackView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(Color.accentColor.opacity(0.1))

            Image(systemName: fallbackIcon)
                .font(.system(size: size * 0.5))
                .foregroundColor(.accentColor)
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
        self.serverType = catalogServer.transport == .sse ? .sse : .http
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
