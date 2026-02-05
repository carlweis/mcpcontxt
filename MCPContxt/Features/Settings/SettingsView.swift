//
//  SettingsView.swift
//  MCPContxt
//
//  Main settings window
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ServersSettingsView()
                .tabItem {
                    Label("Servers", systemImage: "server.rack")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 550, height: 400)
    }
}

#Preview {
    SettingsView()
        .environmentObject(ServerRegistry.shared)
}
