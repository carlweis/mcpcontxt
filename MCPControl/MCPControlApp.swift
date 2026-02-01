//
//  MCPControlApp.swift
//  MCPControl
//
//  Created by Carl on 1/31/26.
//

import SwiftUI

@main
struct MCPControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var registry = ServerRegistry.shared

    var body: some Scene {
        // Menu bar presence
        MenuBarExtra {
            PopoverView()
                .environmentObject(registry)
        } label: {
            MenuBarIconM()
        }
        .menuBarExtraStyle(.window)

        // Settings window (accessible via menu bar)
        Settings {
            SettingsView()
                .environmentObject(registry)
        }
    }

    private var menuBarIconColor: Color {
        switch registry.overallHealthStatus {
        case .healthy:
            return .green
        case .degraded:
            return .yellow
        case .unhealthy:
            return .red
        case .needsAuth:
            return .orange
        case .unknown, .disabled:
            return .gray
        }
    }
}
