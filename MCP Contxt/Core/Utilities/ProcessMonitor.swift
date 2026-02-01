//
//  ProcessMonitor.swift
//  MCP Contxt
//
//  Monitor and control Claude Desktop process
//

import Foundation
import AppKit

class ProcessMonitor {
    static let shared = ProcessMonitor()

    private let claudeDesktopBundleID = "com.anthropic.claudefordesktop"

    private init() {}

    var isClaudeDesktopRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == claudeDesktopBundleID
        }
    }

    var claudeDesktopApp: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == claudeDesktopBundleID
        }
    }

    func launchClaudeDesktop() -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: claudeDesktopBundleID
        ) else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        var success = false
        let semaphore = DispatchSemaphore(value: 0)

        NSWorkspace.shared.openApplication(
            at: url,
            configuration: configuration
        ) { app, error in
            success = app != nil && error == nil
            semaphore.signal()
        }

        semaphore.wait()
        return success
    }

    func quitClaudeDesktop() -> Bool {
        guard let app = claudeDesktopApp else {
            return true // Already not running
        }

        return app.terminate()
    }

    func restartClaudeDesktop() async -> Bool {
        // Quit if running
        if isClaudeDesktopRunning {
            guard quitClaudeDesktop() else {
                return false
            }

            // Wait for termination
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                if !isClaudeDesktopRunning {
                    break
                }
            }

            // Small delay before relaunch
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }

        // Launch
        return launchClaudeDesktop()
    }

    func forceQuitClaudeDesktop() -> Bool {
        guard let app = claudeDesktopApp else {
            return true
        }

        return app.forceTerminate()
    }

    var isClaudeDesktopInstalled: Bool {
        NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: claudeDesktopBundleID
        ) != nil
    }

    var claudeDesktopVersion: String? {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: claudeDesktopBundleID
        ) else {
            return nil
        }

        guard let bundle = Bundle(url: url) else {
            return nil
        }

        return bundle.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
