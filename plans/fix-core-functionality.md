# MCP Contxt - Fix Core Functionality Plan

## Goal

**Make it dead simple for non-technical team members to add MCP servers to Claude Code.**

User flow:
1. Open app from menu bar
2. Click "Browse" to see available MCP servers
3. Find one they want (Linear, Slack, Notion, etc.)
4. Click "Add"
5. Click link to authenticate with that service
6. Start using it in Claude Code

That's it. No config files to edit, no terminal commands, no technical knowledge required.

## Current State

The app has a working UI structure but the core functionality is broken:

1. **Registry browser doesn't work** - URL/network errors when fetching from API
2. **Auto-detection from ~/.claude.json not working** - Servers exist in the file but aren't loaded
3. **Refresh not working** - Button clicks don't trigger any action
4. **Claude Desktop references are irrelevant** - Uses "Connectors" system, not MCP config files

## Root Cause Analysis

### Problem 1: JSON Parsing
The `ClaudeCodeConfigFile` was using complex `AnyCodable` dynamic decoding that fails on the complex nested structures in `~/.claude.json`. The file has many fields beyond just `mcpServers` (tips history, cached configs, oauth data, etc.) and the decoder chokes on some of these.

**Solution**: Simplified decoder that ONLY reads `mcpServers` and ignores everything else. Already partially implemented but needs testing.

### Problem 2: Network Fetch for Registry
The `MCPRegistryService` tries to fetch from `https://api.anthropic.com/mcp-registry/v0/servers` at runtime. This introduces:
- Network dependency
- Potential CORS/sandboxing issues in macOS app
- Unnecessary complexity

**Solution**: Store a static catalog of MCP servers directly in the app code. The registry has ~91 servers - we can hardcode these and update periodically.

### Problem 3: Claude Desktop
Claude Desktop uses a "Connectors" system managed through its Settings UI and cloud sync, NOT the `claude_desktop_config.json` file for MCP servers. The file only exists when users manually configure MCP servers via the old method.

**Solution**: Remove all Claude Desktop sync code. Add info text explaining Claude Desktop uses Connectors.

### Problem 4: Over-Engineering
The app has too many abstraction layers:
- ConfigurationManager -> ClaudeCodeConfig -> ClaudeCodeConfigFile
- SyncService -> ConfigurationManager
- Multiple notification systems
- Complex health monitoring

**Solution**: Simplify to direct file I/O with minimal abstraction.

## Simplified Architecture

```
~/.claude.json (MCP servers live here)
       ↓
 ClaudeConfigService (read/write mcpServers only)
       ↓
    ServerRegistry (in-memory list of servers)
       ↓
      UI Views
```

## Implementation Plan

### Phase 1: Fix JSON Parsing (Critical)

**File: `ClaudeConfigService.swift`** (new, replaces ClaudeCodeConfig)

```swift
import Foundation

class ClaudeConfigService {
    static let shared = ClaudeConfigService()

    private let configURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }()

    struct MCPServerConfig: Codable {
        var type: String?
        var url: String?
        var headers: [String: String]?
        var command: String?
        var args: [String]?
        var env: [String: String]?
    }

    func readServers() -> [String: MCPServerConfig] {
        guard FileManager.default.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mcpServers = json["mcpServers"] as? [String: [String: Any]] else {
            return [:]
        }

        var result: [String: MCPServerConfig] = [:]
        for (name, config) in mcpServers {
            result[name] = MCPServerConfig(
                type: config["type"] as? String,
                url: config["url"] as? String,
                headers: config["headers"] as? [String: String],
                command: config["command"] as? String,
                args: config["args"] as? [String],
                env: config["env"] as? [String: String]
            )
        }
        return result
    }

    func writeServers(_ servers: [String: MCPServerConfig]) throws {
        // Read existing file, update only mcpServers, write back
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: configURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        var mcpDict: [String: [String: Any]] = [:]
        for (name, config) in servers {
            var entry: [String: Any] = [:]
            if let type = config.type { entry["type"] = type }
            if let url = config.url { entry["url"] = url }
            if let headers = config.headers { entry["headers"] = headers }
            if let command = config.command { entry["command"] = command }
            if let args = config.args { entry["args"] = args }
            if let env = config.env { entry["env"] = env }
            mcpDict[name] = entry
        }

        json["mcpServers"] = mcpDict

        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: configURL, options: .atomic)
    }
}
```

Key insight: Use `JSONSerialization` instead of `Codable` to handle the mixed-type JSON without failing on unknown fields.

### Phase 2: Static MCP Catalog

**File: `MCPCatalog.swift`** (new, replaces MCPRegistryService)

Store all 91 servers from the registry as a static array. Example:

```swift
struct MCPCatalogServer: Identifiable {
    let id: String
    let name: String
    let description: String
    let url: String
    let transport: TransportType

    enum TransportType: String {
        case http, sse
    }
}

struct MCPCatalog {
    static let servers: [MCPCatalogServer] = [
        MCPCatalogServer(id: "linear", name: "Linear", description: "Manage issues, projects & workflows", url: "https://mcp.linear.app/mcp", transport: .http),
        MCPCatalogServer(id: "notion", name: "Notion", description: "Connect your Notion workspace", url: "https://mcp.notion.com/mcp", transport: .http),
        MCPCatalogServer(id: "slack", name: "Slack", description: "Send messages and fetch Slack data", url: "https://mcp.slack.com/mcp", transport: .http),
        MCPCatalogServer(id: "github", name: "GitHub", description: "GitHub integration via Copilot", url: "https://api.githubcopilot.com/mcp/", transport: .http),
        MCPCatalogServer(id: "figma", name: "Figma", description: "Generate diagrams and code from Figma", url: "https://mcp.figma.com/mcp", transport: .http),
        // ... all 91 servers
    ]

    static func search(_ query: String) -> [MCPCatalogServer] {
        guard !query.isEmpty else { return servers }
        let q = query.lowercased()
        return servers.filter {
            $0.name.lowercased().contains(q) ||
            $0.description.lowercased().contains(q)
        }
    }
}
```

### Phase 3: Remove Claude Desktop Code

Delete or gut:
- `ClaudeDesktopConfig.swift`
- `SyncTarget.claudeDesktop` case
- All references to syncing to Claude Desktop

Update UI to show:
> "Claude Desktop uses Connectors for MCP integrations. Configure them in Claude Desktop > Settings > Connectors. [Learn more](https://docs.anthropic.com/...)"

### Phase 4: Simplify ServerRegistry

The `ServerRegistry` should:
1. Load servers from `~/.claude.json` on init
2. Provide add/remove/update methods
3. Save changes back to the file
4. Publish changes via `@Published` for SwiftUI

That's it. No health monitoring, no sync services, no enterprise config.

### Phase 5: Simplify UI

**PopoverView**:
- Show list of configured servers from `~/.claude.json`
- "Add" button -> opens server browser
- "Remove" via swipe or context menu

**BrowseServersView**:
- Search/filter the static catalog
- Click "Add" to add server to config
- No network requests needed

**Settings**:
- Info about Claude Desktop Connectors
- Link to documentation
- Maybe app preferences (launch at login)

## Files to Delete

- `ClaudeDesktopConfig.swift`
- `EnterpriseConfigReader.swift`
- `ConfigurationManager.swift` (merge into simpler service)
- `SyncService.swift`
- `HealthMonitor.swift`
- `LogParser.swift`
- `MCPRegistryService.swift`
- `FileWatcher.swift` (not needed for MVP)
- `MenuBarController.swift` (not used with MenuBarExtra)

## Files to Create

- `ClaudeConfigService.swift` - Simple JSON read/write
- `MCPCatalog.swift` - Static server catalog

## Files to Simplify

- `ServerRegistry.swift` - Direct file I/O, no sync complexity
- `SyncTarget.swift` - Remove claudeDesktop, simplify
- `MCPServer.swift` - Remove health status, sync targets
- `PopoverView.swift` - Remove Claude Desktop status
- `BrowseServersView.swift` - Use static catalog

## Testing Checklist

- [ ] App loads servers from `~/.claude.json` on launch
- [ ] Servers display in the menu bar popover
- [ ] "Add" button opens browse view
- [ ] Can search catalog servers
- [ ] Can add server from catalog to config
- [ ] Changes persist to `~/.claude.json`
- [ ] Can remove servers
- [ ] App doesn't crash on malformed JSON

## MCP Server Catalog Data

91 servers available (see fetch output). Key ones:

| Name | URL |
|------|-----|
| Linear | https://mcp.linear.app/mcp |
| Notion | https://mcp.notion.com/mcp |
| Slack | https://mcp.slack.com/mcp |
| GitHub | https://api.githubcopilot.com/mcp/ |
| Figma | https://mcp.figma.com/mcp |
| Asana | https://mcp.asana.com/v2/mcp |
| Atlassian | https://mcp.atlassian.com/v1/mcp |
| HubSpot | https://mcp.hubspot.com/anthropic |
| Stripe | https://mcp.stripe.com |
| Vercel | https://mcp.vercel.com/ |

Full catalog will be embedded in `MCPCatalog.swift`.

## Estimated Effort

- Phase 1 (JSON fix): 30 min
- Phase 2 (Static catalog): 30 min
- Phase 3 (Remove Desktop): 20 min
- Phase 4 (Simplify registry): 30 min
- Phase 5 (Simplify UI): 30 min
- Testing: 30 min

Total: ~3 hours focused work

## Success Criteria

1. Open app -> see servers from `~/.claude.json`
2. Click Browse -> see catalog of 91 servers
3. Search "slack" -> find Slack server
4. Click Add -> server added to config
5. Check `~/.claude.json` -> server is there
6. Restart app -> server still there
