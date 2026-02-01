# MCP Server Icons Implementation Plan

## Overview

Add colorful brand icons to MCP servers by fetching favicons from their service domains. This will make servers more recognizable to end users compared to the current generic SF Symbol icons.

## Current State

- **BrowseServersView.swift**: Uses `serverIcon(for:)` function returning SF Symbol names based on keyword matching
- **ServerRowView.swift**: Uses similar SF Symbol logic based on server type (globe, antenna, terminal)
- **MCPCatalog.swift**: Contains 91 servers with URLs like `https://mcp.slack.com/mcp`, `https://mcp.notion.com/mcp`

## Implementation

### Phase 1: Create FaviconService

Create a new service to fetch and cache favicons from service domains.

**File: `MCPControl/Core/Services/FaviconService.swift`**

```swift
import Foundation
import AppKit

@MainActor
class FaviconService: ObservableObject {
    static let shared = FaviconService()

    @Published private(set) var icons: [String: NSImage] = [:]

    private let cache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private var inFlightRequests: Set<String> = []

    private var cacheDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MCPControl/IconCache")
    }

    func icon(for serverURL: String, serverId: String) -> NSImage? {
        // Check memory cache first
        if let cached = icons[serverId] {
            return cached
        }

        // Check disk cache
        if let diskCached = loadFromDisk(serverId: serverId) {
            icons[serverId] = diskCached
            return diskCached
        }

        // Trigger async fetch if not already in flight
        if !inFlightRequests.contains(serverId) {
            fetchFavicon(for: serverURL, serverId: serverId)
        }

        return nil
    }

    private func fetchFavicon(for serverURL: String, serverId: String) {
        inFlightRequests.insert(serverId)

        Task {
            defer { inFlightRequests.remove(serverId) }

            guard let baseURL = extractBaseDomain(from: serverURL) else { return }

            // Try common favicon locations
            let faviconURLs = [
                "\(baseURL)/favicon.ico",
                "\(baseURL)/favicon.png",
                "\(baseURL)/apple-touch-icon.png",
                "https://www.google.com/s2/favicons?domain=\(baseURL)&sz=64"
            ]

            for urlString in faviconURLs {
                if let image = await downloadImage(from: urlString) {
                    icons[serverId] = image
                    saveToDisk(image: image, serverId: serverId)
                    return
                }
            }
        }
    }

    private func extractBaseDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host else { return nil }

        // For MCP URLs like mcp.slack.com, extract slack.com
        let components = host.components(separatedBy: ".")
        if components.count >= 2 {
            let mainDomain = components.suffix(2).joined(separator: ".")
            return "https://\(mainDomain)"
        }
        return "https://\(host)"
    }

    private func downloadImage(from urlString: String) async -> NSImage? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = NSImage(data: data) else { return nil }
            return image
        } catch {
            return nil
        }
    }

    // Disk caching methods
    private func loadFromDisk(serverId: String) -> NSImage? {
        let fileURL = cacheDirectory.appendingPathComponent("\(serverId).png")
        guard let data = try? Data(contentsOf: fileURL),
              let image = NSImage(data: data) else { return nil }
        return image
    }

    private func saveToDisk(image: NSImage, serverId: String) {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let fileURL = cacheDirectory.appendingPathComponent("\(serverId).png")

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

        try? pngData.write(to: fileURL)
    }
}
```

### Phase 2: Create ServerIconView Component

A reusable SwiftUI view that displays the favicon or falls back to SF Symbol.

**File: `MCPControl/Features/Shared/ServerIconView.swift`**

```swift
import SwiftUI

struct ServerIconView: View {
    let serverId: String
    let serverURL: String?
    let serverType: MCPServerType
    let size: CGFloat

    @StateObject private var faviconService = FaviconService.shared

    var body: some View {
        Group {
            if let url = serverURL,
               let favicon = faviconService.icon(for: url, serverId: serverId) {
                Image(nsImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: size * 0.6))
                    .foregroundColor(.accentColor)
            }
        }
        .frame(width: size, height: size)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(size * 0.2)
    }

    private var fallbackIcon: String {
        switch serverType {
        case .http: return "globe"
        case .sse: return "antenna.radiowaves.left.and.right"
        case .stdio: return "terminal"
        }
    }
}
```

### Phase 3: Update BrowseServersView

Replace the SF Symbol icon with `ServerIconView`.

**Changes to `BrowseServersView.swift`:**

```swift
// In serverCard function, replace the Icon VStack:
VStack {
    ServerIconView(
        serverId: server.id,
        serverURL: server.url,
        serverType: server.transport == .sse ? .sse : .http,
        size: 40
    )
}

// Remove the serverIcon(for:) function entirely
```

### Phase 4: Update ServerRowView

Replace the SF Symbol icon with `ServerIconView`.

**Changes to `ServerRowView.swift`:**

```swift
// Replace:
Image(systemName: serverIcon)
    .font(.caption)
    .foregroundColor(.accentColor)
    .frame(width: 16)

// With:
ServerIconView(
    serverId: server.name,
    serverURL: server.configuration.url,
    serverType: server.type,
    size: 24
)
```

### Phase 5: Update MCPCatalogServer

Add a computed property to help with favicon domain extraction.

**Changes to `MCPCatalog.swift`:**

```swift
struct MCPCatalogServer: Identifiable, Hashable {
    // ... existing properties ...

    /// Extracts the main service domain from the MCP URL
    var serviceDomain: String? {
        guard let url = URL(string: url),
              let host = url.host else { return nil }
        let components = host.components(separatedBy: ".")
        if components.count >= 2 {
            return components.suffix(2).joined(separator: ".")
        }
        return host
    }
}
```

### Phase 6: New App Icon

Create a new app icon featuring a robot with a green status indicator.

**Design specifications:**
- Primary shape: Stylized robot head/face
- Color scheme:
  - Robot: Dark gray/black body (#333)
  - Eyes: Blue accent (#007AFF)
  - Green status dot: #34C759 (Apple's system green)
- Status indicator: Small green circle in top-right corner (like a notification badge)
- Style: Modern, minimal, flat design consistent with macOS Big Sur+ iconography

**Files to create:**
- `MCPControl/Assets.xcassets/AppIcon.appiconset/icon_16x16.png`
- `MCPControl/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png`
- `MCPControl/Assets.xcassets/AppIcon.appiconset/icon_32x32.png`
- `MCPControl/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png`
- `MCPControl/Assets.xcassets/AppIcon.appiconset/icon_128x128.png`
- `MCPControl/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png`
- `MCPControl/Assets.xcassets/AppIcon.appiconset/icon_256x256.png`
- `MCPControl/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png`
- `MCPControl/Assets.xcassets/AppIcon.appiconset/icon_512x512.png`
- `MCPControl/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png`

Update `Contents.json` with proper references.

## File Changes Summary

| File | Action | Description |
|------|--------|-------------|
| `Core/Services/FaviconService.swift` | Create | Favicon fetching and caching service |
| `Features/Shared/ServerIconView.swift` | Create | Reusable icon component with fallback |
| `Features/ServerManagement/BrowseServersView.swift` | Modify | Use ServerIconView, remove serverIcon() |
| `Features/MenuBar/ServerRowView.swift` | Modify | Use ServerIconView |
| `Core/Services/MCPCatalog.swift` | Modify | Add serviceDomain computed property |
| `Assets.xcassets/AppIcon.appiconset/*` | Create | New robot app icon with status dot |

## Technical Notes

1. **Favicon Sources Priority:**
   - Direct `/favicon.ico` or `/favicon.png` from main domain
   - Apple touch icon for higher resolution
   - Google Favicon service as fallback (always works)

2. **Caching Strategy:**
   - Memory cache via `@Published` dictionary for instant access
   - Disk cache in `~/Library/Application Support/MCPControl/IconCache/`
   - Icons fetched async on first view, updates reactively

3. **Domain Extraction:**
   - MCP URLs like `https://mcp.slack.com/mcp` → extract `slack.com`
   - Fetch favicon from `https://slack.com/favicon.ico`

4. **Fallback Behavior:**
   - While loading: Show SF Symbol based on transport type
   - If fetch fails: Keep showing SF Symbol
   - No broken image states

## Testing Checklist

- [ ] FaviconService fetches icons correctly
- [ ] Icons appear in BrowseServersView
- [ ] Icons appear in ServerRowView (popover list)
- [ ] Disk cache persists across app restarts
- [ ] Fallback SF Symbols work when favicon unavailable
- [ ] No memory leaks from retained images
- [ ] App icon displays correctly in Dock, menu bar, About window
