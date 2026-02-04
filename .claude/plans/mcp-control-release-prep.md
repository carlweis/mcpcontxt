# MCP Control - Release Preparation Plan

## Project Info

- **Version**: 1.0.0
- **Repository**: github.com/carlweis/mcpcontxt
- **Website**: mcpcontxt.com
- **Bundle ID**: com.carlweis.MCPControl

## Summary

This plan covers three main areas:
1. **Fix navigation bug**: Enable clicking on installed servers in the Browse view to navigate to their detail page
2. **Add DMG build automation**: Create scripts to build, sign, notarize, and package the app as a DMG for distribution
3. **Pre-release review**: Identify and fix any remaining issues before public release

## Issue Analysis

### Navigation Bug
In `BrowseServersView.swift`, the server cards display installed servers (with green "Added" badge) but don't have click handlers. Users expect to click on an installed server to view its details, but currently nothing happens.

**Root cause**: The `serverCard()` function renders cards without tap gestures. Only "Add" and "Configure" buttons are actionable.

**Solution**: Make the entire card clickable for installed servers, navigating to `ServerDetailView`.

## Implementation Steps

### 1. Fix Browse View Navigation to Server Details

**File to modify**: `MCPControl/Features/ServerManagement/BrowseServersView.swift`

Changes needed:
- [ ] Add a tap gesture to `serverCard()` that triggers navigation when the server is installed
- [ ] Look up the installed `MCPServer` from `registry.servers` by matching on server ID/name
- [ ] Post `.openServerDetail` notification with the `MCPServer` object
- [ ] Add visual feedback (hover effect or cursor change) to indicate clickability

```swift
// In serverCard(_:) function, wrap the card in a button or add onTapGesture:
private func serverCard(_ server: MCPCatalogServer) -> some View {
    let isInstalled = isServerInstalled(server)

    return HStack(alignment: .top, spacing: 12) {
        // ... existing card content ...
    }
    .padding()
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(8)
    .contentShape(Rectangle()) // Make entire area tappable
    .onTapGesture {
        if isInstalled, let installedServer = registry.server(withName: server.id) {
            NotificationCenter.default.post(name: .openServerDetail, object: installedServer)
        }
    }
    .onHover { hovering in
        if isInstalled {
            NSCursor.pointingHand.set()
        }
    }
}
```

### 2. Create DMG Build Script

**File to create**: `scripts/build-dmg.sh`

This script will:
- [ ] Build the app in Release configuration using `xcodebuild`
- [ ] Sign the app with Developer ID certificate (if available)
- [ ] Notarize the app with Apple (if credentials provided)
- [ ] Create a DMG with a nice background and Applications folder alias
- [ ] Output the final DMG to `dist/` directory

```bash
#!/bin/bash
set -e

# Build configuration
APP_NAME="MCPControl"
SCHEME="MCPControl"
VERSION="1.0.0"
BUILD_DIR="build"
DIST_DIR="dist"

# Signing configuration (set these or use environment variables)
DEVELOPER_ID="${DEVELOPER_ID:-Developer ID Application: Your Name (TEAM_ID)}"
APPLE_ID="${APPLE_ID:-your@email.com}"
TEAM_ID="${TEAM_ID:-YOUR_TEAM_ID}"
APP_PASSWORD="${APP_PASSWORD:-xxxx-xxxx-xxxx-xxxx}"  # App-specific password

# Steps:
# 1. Clean and build release
xcodebuild -scheme "$SCHEME" -configuration Release -derivedDataPath "$BUILD_DIR" clean build

# 2. Code sign with Developer ID
codesign --deep --force --verify --verbose \
  --sign "$DEVELOPER_ID" \
  --options runtime \
  "$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

# 3. Create DMG with create-dmg
create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 150 185 \
  --app-drop-link 450 185 \
  "$DIST_DIR/$APP_NAME-$VERSION.dmg" \
  "$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

# 4. Notarize the DMG
xcrun notarytool submit "$DIST_DIR/$APP_NAME-$VERSION.dmg" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_PASSWORD" \
  --wait

# 5. Staple the notarization ticket
xcrun stapler staple "$DIST_DIR/$APP_NAME-$VERSION.dmg"

echo "Done! DMG ready at: $DIST_DIR/$APP_NAME-$VERSION.dmg"
```

**Note**: You'll need an app-specific password for notarization:
1. Go to appleid.apple.com → Sign-In and Security → App-Specific Passwords
2. Generate a new password for "MCP Control Notarization"
3. Use this password in the script (or set `APP_PASSWORD` env var)

**Dependencies to install** (document in README):
- `create-dmg` (via Homebrew: `brew install create-dmg`) - optional but recommended
- Developer ID Application certificate (for signing)
- Apple ID with app-specific password (for notarization)

### 3. Add Makefile for Common Tasks

**File to create**: `Makefile`

```makefile
.PHONY: build release dmg clean

build:
	xcodebuild -scheme MCPControl -configuration Debug build

release:
	xcodebuild -scheme MCPControl -configuration Release build

dmg: release
	./scripts/build-dmg.sh

clean:
	rm -rf build/ dist/
	xcodebuild clean -scheme MCPControl
```

### 4. Pre-Release Code Review Checklist

Review and fix these areas before release:

#### 4.1 App Metadata
- [ ] Verify bundle identifier: `com.carlweis.MCPControl`
- [ ] Set version number in Xcode (CFBundleShortVersionString)
- [ ] Set build number in Xcode (CFBundleVersion)
- [ ] Verify app icon is correct in all sizes
- [ ] Update copyright year in About view

#### 4.2 Code Quality
- [ ] Remove all `print()` debug statements or replace with proper logging
- [ ] Review error handling - ensure user-friendly error messages
- [ ] Test with no servers configured (empty state)
- [ ] Test with many servers (performance)

#### 4.3 User Experience
- [ ] Verify all windows close properly with Escape key
- [ ] Test menu bar icon in light and dark mode
- [ ] Verify status indicators update correctly
- [ ] Test adding, editing, and removing servers

#### 4.4 Security Review
- [ ] Ensure no hardcoded credentials or API keys
- [ ] Verify OAuth tokens are stored securely (Keychain)
- [ ] Review entitlements file for minimal required permissions
- [ ] Test that the app works with sandbox enabled (currently disabled)

#### 4.5 Documentation
- [ ] Update README.md with installation instructions
- [ ] Add CHANGELOG.md for version history
- [ ] Document the DMG build process

### 5. Update README with Installation Instructions

**File to modify**: `README.md` (create if doesn't exist)

Add:
- [ ] Project description
- [ ] Installation instructions (drag to Applications)
- [ ] How to configure MCP servers
- [ ] Troubleshooting section
- [ ] Build from source instructions

## Files to Modify

| File | Changes |
|------|---------|
| `MCPControl/Features/ServerManagement/BrowseServersView.swift` | Add tap gesture for navigation to server details |

## Files to Create

| File | Purpose |
|------|---------|
| `scripts/build-dmg.sh` | Automated DMG build, signing, and notarization |
| `Makefile` | Common build tasks |
| `README.md` | Project documentation (if doesn't exist) |
| `CHANGELOG.md` | Version history |
| `dist/.gitkeep` | Distribution output directory |

## Patterns to Follow

- Navigation uses `NotificationCenter.default.post(name:object:)` pattern
- Windows are managed in `AppDelegate.swift`
- Server lookup: `registry.server(withName: serverName)` returns `MCPServer?`

## Build & Distribution Flow

```
1. Developer runs: make dmg
   └── scripts/build-dmg.sh
       ├── xcodebuild (Release build)
       ├── codesign (sign with Developer ID)
       ├── create-dmg (package as DMG)
       └── xcrun notarytool (notarize with Apple)

2. Output: dist/MCPControl-1.0.0.dmg
   └── Upload to website for download
```

## Additional Tasks

### Update Catalog URL
The app currently fetches the catalog from the old repo. Update to new location:

**File**: `MCPControl/Core/Services/MCPCatalogService.swift`
- [ ] Change catalog URL from `opcodezerohq/mcp-control` to `carlweis/mcpcontxt`

### Update Bundle Identifier (if needed)
Verify the bundle ID matches your Developer ID certificate:
- Current: `com.carlweis.MCPControl`
- Should match what's registered in Apple Developer Portal

## Resolved Questions

- **Version**: 1.0.0
- **Code signing**: Yes - Developer ID certificate to be created
- **Notarization**: Yes - will provide smoother install experience
- **Repository**: github.com/carlweis/mcpcontxt
- **Website**: mcpcontxt.com

---

## Future Considerations

### Enterprise Catalog Sources (Pro/Enterprise Feature)

**Problem**: Companies may want to control which MCP servers employees can install - limiting to approved/vetted servers only.

**Solution**: Make the catalog source configurable.

**UI Concept**:
```
Settings > Advanced
├── Catalog Sources
│   ├── [x] Default (mcpcontxt.com)
│   ├── [ ] Acme Corp (internal.acme.com/mcp-catalog)
│   └── + Add Custom Source...
├── [ ] Only allow servers from enabled catalogs
└── [ ] Allow manually adding unlisted servers
```

**Features**:
- Support multiple catalog sources (URLs to JSON files matching the existing schema)
- Enterprise admins could host their own catalog with approved servers only
- Option to disable the default public catalog entirely
- Could integrate with MDM for pushing catalog configurations
- Audit logging for which servers are installed

**Implementation Notes**:
- Catalog URL currently hardcoded in `MCPCatalogService.swift`
- Would need to refactor to support multiple sources
- Merge/dedupe servers from multiple catalogs
- Consider caching strategy for multiple sources

**Monetization Angle**: This is a natural "Pro" or "Enterprise" tier feature. Free tier uses default catalog only, paid tiers get custom sources.
