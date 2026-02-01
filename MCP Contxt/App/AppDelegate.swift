//
//  AppDelegate.swift
//  MCP Contxt
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up as menu bar app (no dock icon by default)
        NSApp.setActivationPolicy(.accessory)

        // Initialize services
        Task { @MainActor in
            await initializeServices()
        }

        // Setup notifications
        setupNotifications()

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
    }

    func applicationWillTerminate(_ notification: Notification) {
        HealthMonitor.shared.stopMonitoring()
        ConfigurationFileWatcher.shared.stopWatching()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when windows close - we're a menu bar app
        return false
    }

    private func initializeServices() async {
        // Load server registry
        await ServerRegistry.shared.load()

        // Start health monitoring
        let interval = UserDefaults.standard.double(forKey: "healthCheckInterval")
        HealthMonitor.shared.startMonitoring(interval: interval > 0 ? interval : 30)

        // Start file watching
        ConfigurationFileWatcher.shared.startWatching {
            // Handle external config changes
            Task { @MainActor in
                // Could show a notification or badge indicating external changes
            }
        }

        // Auto-sync on launch if enabled
        if UserDefaults.standard.bool(forKey: "autoSyncOnChanges") {
            SyncService.shared.setAutoSync(enabled: true)
        }

        // First launch: Discover and import existing servers
        if !UserDefaults.standard.bool(forKey: "hasCompletedFirstLaunch") {
            await performFirstLaunchSetup()
        }
    }

    private func performFirstLaunchSetup() async {
        do {
            let result = try await ConfigurationManager.shared.discoverExistingServers()

            if result.hasServers {
                // Import all discovered servers
                try await ConfigurationManager.shared.importDiscoveredServers(result.mergedServers)
            }

            UserDefaults.standard.set(true, forKey: "hasCompletedFirstLaunch")
        } catch {
            // Handle silently on first launch
        }
    }

    private func setupNotifications() {
        // Request notification permission
        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }

        // Setup notification categories
        NotificationService.shared.setupNotificationCategories()

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // Handle notification actions
        NotificationDelegate.shared.onRestartServer = { serverName in
            Task {
                _ = await ProcessMonitor.shared.restartClaudeDesktop()
            }
        }

        NotificationDelegate.shared.onViewDetails = { serverName in
            // With MenuBarExtra, we can't programmatically open the popover
            // Instead, activate the app so the user can click the menu bar icon
            Task { @MainActor in
                NSApp.activate(ignoringOtherApps: true)
            }
        }
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
            settingsWindow?.title = "MCP Contxt Settings"
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

    private var browseWindow: NSWindow?

    @objc func openBrowse() {
        if browseWindow == nil {
            let browseView = BrowseServersView(onDismiss: { [weak self] in
                self?.browseWindow?.close()
            })
            .environmentObject(ServerRegistry.shared)

            browseWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 550),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            browseWindow?.title = "Browse MCP Servers"
            browseWindow?.contentView = NSHostingView(rootView: browseView)
            browseWindow?.center()
            browseWindow?.isReleasedWhenClosed = false
        }

        browseWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
