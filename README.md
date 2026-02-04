# MCP Contxt

**The missing management interface for MCP servers in Claude Code.**

MCP Contxt is a native macOS menu bar app that makes it easy to discover, install, and manage [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) servers for Claude Code and Claude Desktop.

**Website:** [mcpcontxt.com](https://mcpcontxt.com)

---

## What is MCP?

The Model Context Protocol (MCP) allows Claude to securely connect to external tools and data sources. With MCP servers, Claude can:

- Access your project management tools (Jira, Linear, Asana)
- Query your databases and analytics platforms
- Interact with your CRM (HubSpot, Salesforce)
- Connect to hundreds of other services

**The problem:** Managing MCP servers currently requires manually editing JSON configuration files. MCP Contxt provides a visual interface to browse, install, and manage these connections.

---

## Features

### Browse & Install Servers
Discover 100+ MCP servers from a curated catalog. One-click installation for most servers.

### Menu Bar Access
Always-accessible menu bar icon shows your server status at a glance. Quick access to all your configured servers.

### Visual Management
See all your MCP servers in one place. Add, remove, and configure servers without editing JSON files.

### Works with Claude Code
Changes sync directly to your Claude Code configuration. No restart required.

---

## Installation

### Download
1. Download the latest release from [mcpcontxt.com](https://mcpcontxt.com) or the [GitHub Releases](https://github.com/carlweis/mcpcontxt/releases) page
2. Open the DMG file
3. Drag **MCP Contxt** to your Applications folder
4. Launch MCP Contxt from Applications

### First Launch
On first launch, you may see a security prompt. Click **Open** to allow the app to run. MCP Contxt needs access to your home directory to read and write the Claude Code configuration file (`~/.claude.json`).

---

## How to Use

### Step 1: Browse Available Servers

1. Click the **MCP Contxt icon** in your menu bar
2. Click the **Browse** button
3. Search or scroll through available servers
4. Click **Add** to install a server, or **Configure** for servers that need credentials

### Step 2: Authenticate in Claude Code

After adding servers, you need to authenticate them in Claude Code:

1. Open your terminal
2. Run Claude Code: `claude`
3. Type `/mcp` to see your MCP servers
4. Select the server you want to authenticate
5. Follow the authentication prompts (usually opens a browser for OAuth)

Once authenticated, Claude can use that server's tools in your conversations.

### Step 3: Use MCP Servers in Claude

After authentication, simply ask Claude to use the connected service:

> "Check my Linear issues"
> "What's in my Notion workspace?"
> "Show me recent Slack messages"

Claude will automatically use the appropriate MCP server.

---

## Managing Your Servers

### View Installed Servers
Click the menu bar icon to see all your configured servers with their status.

### Remove a Server
1. Click on a server in the menu bar popover
2. Click **Remove Server** in the detail view

### Import from Claude Desktop
If you have servers configured in Claude Desktop, you can import them:
1. Click **Add** > **Import from Claude Desktop**
2. Select the servers you want to import

---

## How It Works

MCP Contxt manages the Claude Code configuration file located at `~/.claude.json`. When you add or remove servers through the app, it updates this file directly.

```
You ─── MCP Contxt ─── ~/.claude.json ─── Claude Code
              │
              └── Server Catalog (GitHub)
```

The app fetches available servers from a curated catalog and writes your selections to the Claude Code config. Claude Code automatically detects changes to this file.

---

## Frequently Asked Questions

### Do I need to restart Claude Code after adding a server?
No. Claude Code automatically detects configuration changes.

### Why do some servers require configuration?
Servers marked "stdio" run locally on your machine and may need API keys or credentials. The app will prompt you to enter these when you add the server.

### Where is my data stored?
- Server configuration: `~/.claude.json`
- App preferences: `~/Library/Application Support/MCPControl/`
- No data is sent to external servers (except fetching the server catalog)

### Can I still edit the config file manually?
Yes. MCP Contxt reads from `~/.claude.json` on launch. Manual changes will appear in the app after refreshing.

---

## Claude Code Documentation

For more information about MCP servers and Claude Code:

- [Model Context Protocol Overview](https://modelcontextprotocol.io/)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [MCP Server Directory](https://github.com/modelcontextprotocol/servers)
- [Building MCP Servers](https://modelcontextprotocol.io/docs/concepts/servers)

---

## Tech Stack

For developers interested in contributing:

| Component | Technology |
|-----------|------------|
| Language | Swift 6.0 |
| UI Framework | SwiftUI |
| Platform | macOS 15.0+ (Sequoia) |
| IDE | Xcode 16+ |
| Architecture | MVVM with Services |

### Building from Source

```bash
# Clone the repository
git clone https://github.com/carlweis/mcpcontxt.git
cd mcpcontxt

# Open in Xcode
open MCPControl.xcodeproj

# Or build from command line
make build      # Debug build
make release    # Release build
make dmg        # Create distributable DMG
```

### Project Structure

```
MCPControl/
├── App/                    # App delegate, menu bar setup
├── Features/
│   ├── MenuBar/           # Popover and server list
│   ├── ServerManagement/  # Browse, add, configure servers
│   └── Settings/          # App preferences
├── Core/
│   ├── Models/            # Data models
│   ├── Services/          # Business logic
│   └── Utilities/         # Helpers
└── Resources/             # Assets, catalog data
```

---

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Support

- **Issues:** [GitHub Issues](https://github.com/carlweis/mcpcontxt/issues)
- **Website:** [mcpcontxt.com](https://mcpcontxt.com)

---

Built with care for the Claude community.
