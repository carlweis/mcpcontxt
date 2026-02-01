//
//  ContentView.swift
//  MCPControl
//
//  This file is kept for compatibility but the app runs as a menu bar app.
//  See PopoverView for the main UI.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("MCP Control")
                .font(.title)

            Text("This app runs in the menu bar.\nLook for the status icon at the top of your screen.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(minWidth: 300, minHeight: 200)
    }
}

#Preview {
    ContentView()
}
