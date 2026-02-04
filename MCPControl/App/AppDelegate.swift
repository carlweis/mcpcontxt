//
//  AppDelegate.swift
//  MCPControl
//
//  NSApplicationDelegate for menu bar app functionality
//

import SwiftUI
import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?
    private var addServerWindow: NSWindow?
    private var importWindow: NSWindow?
    private var serverDetailWindow: NSWindow?
    private var browseWindow: NSWindow?
    private var stdioConfigWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up as menu bar app (no dock icon by default)
        NSApp.setActivationPolicy(.accessory)

        // Load servers from ~/.claude.json
        Task { @MainActor in
            await ServerRegistry.shared.loadFromClaudeConfig()
        }

        // Watch for window open requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .openSettings,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openAddServer),
            name: .openAddServer,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openImport),
            name: .openImport,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openBrowse),
            name: .openBrowse,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenServerDetail(_:)),
            name: .openServerDetail,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenStdioServerConfig(_:)),
            name: .openStdioServerConfig,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when windows close - we're a menu bar app
        return false
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(ServerRegistry.shared)

            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 550, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "MCP Control Settings"
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openAddServer() {
        if addServerWindow == nil {
            let addServerView = AddServerView(onDismiss: { [weak self] in
                self?.addServerWindow?.close()
            })
            .environmentObject(ServerRegistry.shared)

            addServerWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            addServerWindow?.title = "Add MCP Server"
            addServerWindow?.contentView = NSHostingView(rootView: addServerView)
            addServerWindow?.center()
            addServerWindow?.isReleasedWhenClosed = false
        }

        addServerWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openImport() {
        if importWindow == nil {
            let importView = ImportServersView(onDismiss: { [weak self] in
                self?.importWindow?.close()
            })
            .environmentObject(ServerRegistry.shared)

            importWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            importWindow?.title = "Import MCP Servers"
            importWindow?.contentView = NSHostingView(rootView: importView)
            importWindow?.center()
            importWindow?.isReleasedWhenClosed = false
        }

        importWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleOpenServerDetail(_ notification: Notification) {
        guard let server = notification.object as? MCPServer else { return }
        openServerDetail(server)
    }

    func openServerDetail(_ server: MCPServer) {
        let detailView = ServerDetailView(server: server, onDismiss: { [weak self] in
            self?.serverDetailWindow?.close()
        })
        .environmentObject(ServerRegistry.shared)

        if serverDetailWindow == nil {
            serverDetailWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            serverDetailWindow?.isReleasedWhenClosed = false
        }

        serverDetailWindow?.title = server.name
        serverDetailWindow?.contentView = NSHostingView(rootView: detailView)
        serverDetailWindow?.center()
        serverDetailWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openBrowse() {
        // Always create fresh view to ensure catalog refresh
        let browseView = BrowseServersView(onDismiss: { [weak self] in
            self?.browseWindow?.close()
        })
        .environmentObject(ServerRegistry.shared)

        if browseWindow == nil {
            browseWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 550),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            browseWindow?.title = "Browse MCP Servers"
            browseWindow?.center()
            browseWindow?.isReleasedWhenClosed = false
        }

        browseWindow?.contentView = NSHostingView(rootView: browseView)
        browseWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleOpenStdioServerConfig(_ notification: Notification) {
        guard let catalogServer = notification.object as? MCPCatalogServer else { return }
        openStdioServerConfig(catalogServer)
    }

    func openStdioServerConfig(_ catalogServer: MCPCatalogServer) {
        let configView = AddStdioServerView(catalogServer: catalogServer, onDismiss: { [weak self] in
            self?.stdioConfigWindow?.close()
        })
        .environmentObject(ServerRegistry.shared)

        if stdioConfigWindow == nil {
            stdioConfigWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            stdioConfigWindow?.isReleasedWhenClosed = false
        }

        stdioConfigWindow?.title = "Configure \(catalogServer.name)"
        stdioConfigWindow?.contentView = NSHostingView(rootView: configView)
        stdioConfigWindow?.center()
        stdioConfigWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
