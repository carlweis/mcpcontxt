//
//  MCPStatusChecker.swift
//  MCPContxt
//
//  Checks MCP server connection status by running `claude mcp` CLI
//

import Foundation
import Combine

enum MCPConnectionStatus: String {
    case unknown
    case connected
    case needsAuth
    case failed
}

class MCPStatusChecker: ObservableObject {
    static let shared = MCPStatusChecker()

    @Published var statuses: [String: MCPConnectionStatus] = [:]
    @Published var isChecking = false
    @Published var lastChecked: Date?
    @Published var error: String?

    private init() {}

    /// Refresh status for all configured MCP servers
    func refresh() async {
        isChecking = true
        error = nil
        defer { isChecking = false }

        do {
            let output = try await runClaudeMCP()
            parseOutput(output)
            lastChecked = Date()
        } catch {
            self.error = error.localizedDescription
            print("[MCPStatusChecker] Error: \(error)")
        }
    }

    /// Run `claude mcp` command and return output
    private func runClaudeMCP() async throws -> String {
        let process = Process()
        let pipe = Pipe()

        // Try to find claude in common locations
        let claudePaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(NSHomeDirectory())/.local/bin/claude",
            "/usr/bin/claude"
        ]

        var claudePath: String?
        for path in claudePaths {
            if FileManager.default.fileExists(atPath: path) {
                claudePath = path
                break
            }
        }

        // Fall back to PATH lookup
        if claudePath == nil {
            claudePath = "/usr/bin/env"
            process.arguments = ["claude", "mcp", "list"]
        } else {
            process.executableURL = URL(fileURLWithPath: claudePath!)
            process.arguments = ["mcp", "list"]
        }

        if process.executableURL == nil {
            process.executableURL = URL(fileURLWithPath: claudePath!)
        }

        process.standardOutput = pipe
        process.standardError = pipe

        // Set up environment to include common paths
        var env = ProcessInfo.processInfo.environment
        let additionalPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(NSHomeDirectory())/.local/bin"
        ]
        if let existingPath = env["PATH"] {
            env["PATH"] = additionalPaths.joined(separator: ":") + ":" + existingPath
        }
        process.environment = env

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()

                DispatchQueue.global().async {
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "MCPStatusChecker",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: "claude mcp failed: \(output)"]
                        ))
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Parse `claude mcp list` output to extract server statuses
    /// Format: "servername: url (type) - ✓ Connected"
    func parseOutput(_ output: String) {
        var newStatuses: [String: MCPConnectionStatus] = [:]

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            // Skip header/empty lines
            if line.contains("Checking") || line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }

            // Parse: "slack: https://mcp.slack.com/mcp (HTTP) - ✗ Failed to connect"
            if let match = parseStatusLine(line) {
                newStatuses[match.name] = match.status
            }
        }

        statuses = newStatuses
        print("[MCPStatusChecker] Parsed \(newStatuses.count) server statuses: \(newStatuses)")
    }

    func parseStatusLine(_ line: String) -> (name: String, status: MCPConnectionStatus)? {
        // Format: "servername: url (type) - status"
        // First, get the server name (everything before the first colon)
        guard let colonIndex = line.firstIndex(of: ":") else {
            return nil
        }

        let name = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)

        // Determine status from the end of the line
        let status: MCPConnectionStatus
        if line.contains("✓") || line.lowercased().contains("connected") {
            status = .connected
        } else if line.contains("!") || line.lowercased().contains("needs authentication") {
            status = .needsAuth
        } else if line.contains("✗") || line.lowercased().contains("failed") {
            status = .failed
        } else {
            status = .unknown
        }

        return (name, status)
    }

    /// Get status for a specific server
    func status(for serverName: String) -> MCPConnectionStatus {
        statuses[serverName] ?? .unknown
    }
}
