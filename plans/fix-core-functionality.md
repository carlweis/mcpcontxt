# MCP Contxt - Fix Core Functionality Plan

## Status: IMPLEMENTED

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

## Implementation Summary

### New Files Created

1. **`ClaudeConfigService.swift`** - Simple JSON read/write for ~/.claude.json
   - Uses JSONSerialization instead of Codable to handle complex JSON
   - Only reads/writes mcpServers, preserves other fields
   - Methods: readServers(), addServer(), removeServer(), writeServers()

2. **`MCPCatalog.swift`** - Static catalog of 91 MCP servers
   - No network requests needed
   - Embedded data from Anthropic's MCP registry
   - Search function for filtering

### Files Updated

1. **`BrowseServersView.swift`** - Now uses static MCPCatalog
   - No loading states or network errors
   - Instant search and display
   - Direct add via ClaudeConfigService

2. **`ServerRegistry.swift`** - Simplified to load from ~/.claude.json
   - Uses ClaudeConfigService.readServers()
   - Direct CRUD via ClaudeConfigService
   - No more servers.json file

3. **`PopoverView.swift`** - Simplified UI
   - Removed sync status bar
   - Removed Claude Desktop references
   - Direct remove via registry

4. **`ServerRowView.swift`** - Simplified
   - Removed health status
   - Simple delete action

5. **`MenuBarController.swift`** - Simplified
   - Removed SyncService
   - Uses registry.loadFromClaudeConfig()

6. **`AppDelegate.swift`** - Simplified
   - Removed HealthMonitor, ConfigurationFileWatcher, SyncService
   - Just loads ServerRegistry on launch

7. **`AddServerView.swift`** - Uses ClaudeConfigService
   - Removed sync targets section
   - Direct save to ~/.claude.json

8. **`ImportServersView.swift`** - Simplified
   - Shows servers from ~/.claude.json
   - No more complex discovery

9. **`ServerDetailView.swift`** - Simplified
   - Removed logs/errors tabs
   - Shows configuration and auth link

10. **`GeneralSettingsView.swift`** - Simplified
    - Removed health monitoring settings
    - Added Claude Desktop Connectors info

11. **`AdvancedSettingsView.swift`** - Simplified
    - Removed Claude Desktop status
    - Shows debug info for ClaudeConfigService

12. **`ServerListView.swift`** - Simplified
    - Removed SyncService dependency
    - Direct delete via registry

## Architecture

```
~/.claude.json (MCP servers live here)
       ↓
 ClaudeConfigService (read/write mcpServers only)
       ↓
    ServerRegistry (in-memory list + CRUD)
       ↓
      UI Views
```

## Files That Can Be Removed (Not Used)

The following files are no longer referenced by the updated code:
- `ClaudeDesktopConfig.swift`
- `EnterpriseConfigReader.swift`
- `ConfigurationManager.swift`
- `SyncService.swift`
- `HealthMonitor.swift`
- `LogParser.swift`
- `MCPRegistryService.swift`
- `FileWatcher.swift`
- `ProcessMonitor.swift`

Note: These files may still exist but are not used by the simplified architecture.

## Testing Checklist

- [x] ClaudeConfigService.readServers() works
- [x] ClaudeConfigService.addServer() works
- [x] ClaudeConfigService.removeServer() works
- [ ] App loads servers from ~/.claude.json on launch
- [ ] Servers display in the menu bar popover
- [ ] "Browse" button opens browse view
- [ ] Can search catalog servers
- [ ] Can add server from catalog to config
- [ ] Changes persist to ~/.claude.json
- [ ] Can remove servers
- [ ] App doesn't crash on malformed JSON

## MCP Server Catalog

91 servers embedded in MCPCatalog.swift including:
- Linear, Notion, Slack, GitHub, Figma
- Asana, Atlassian, HubSpot, Stripe, Vercel
- And 81 more...

## Success Criteria

1. Open app → see servers from ~/.claude.json
2. Click Browse → see catalog of 91 servers
3. Search "slack" → find Slack server
4. Click Add → server added to config
5. Check ~/.claude.json → server is there
6. Restart app → server still there
