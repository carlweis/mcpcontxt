//
//  MenuBarController.swift
//  MCP Control
//
//  Manages the NSStatusItem and popover for the menu bar
//

import SwiftUI
import AppKit
import Combine

@MainActor
class MenuBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    @Published var isPopoverShown: Bool = false

    private let registry: ServerRegistry

    init(registry: ServerRegistry = .shared) {
        self.registry = registry
        super.init()
    }

    func setup() {
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateStatusIcon()
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create the popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environmentObject(registry)
                .environmentObject(self)
        )

        // Setup event monitor to close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }

        // Observe server changes
        registry.$servers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)
    }

    func teardown() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        statusItem = nil
        popover = nil
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            showPopover()
            return
        }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            if isPopoverShown {
                closePopover()
            } else {
                showPopover()
            }
        }
    }

    func showPopover() {
        guard let button = statusItem?.button,
              let popover = popover else { return }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isPopoverShown = true
    }

    func closePopover() {
        popover?.performClose(nil)
        isPopoverShown = false
    }

    private func showContextMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Open MCP Control", action: #selector(showPopoverFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refreshServers), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit MCP Control", action: #selector(quitApp), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func showPopoverFromMenu() {
        showPopover()
    }

    @objc private func refreshServers() {
        Task {
            await registry.loadFromClaudeConfig()
        }
    }

    @objc private func openSettings() {
        closePopover()
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }

        let hasServers = !registry.servers.isEmpty

        // Use SF Symbols for the menu bar icon
        let imageName = hasServers ? "circle.fill" : "circle"
        let tintColor: NSColor = hasServers ? .systemGreen : .secondaryLabelColor

        if let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "MCP Contxt") {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            let configuredImage = image.withSymbolConfiguration(config)
            button.image = configuredImage
            button.contentTintColor = tintColor
        }

        let serverCount = registry.servers.count
        let statusText = serverCount == 0 ? "No servers" : "\(serverCount) server\(serverCount == 1 ? "" : "s")"
        button.toolTip = "MCP Contxt - \(statusText)"
    }
}
