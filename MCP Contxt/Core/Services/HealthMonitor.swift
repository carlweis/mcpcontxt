//
//  HealthMonitor.swift
//  MCP Contxt
//
//  Monitor server health and connection status
//

import Foundation
import Combine

@MainActor
class HealthMonitor: ObservableObject {
    static let shared = HealthMonitor()

    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var lastCheckAt: Date?

    private let registry: ServerRegistry
    private let logParser: LogParser
    private var monitoringTask: Task<Void, Never>?
    private var checkInterval: TimeInterval = 30

    private init(
        registry: ServerRegistry = .shared,
        logParser: LogParser = .shared
    ) {
        self.registry = registry
        self.logParser = logParser
    }

    func startMonitoring(interval: TimeInterval = 30) {
        checkInterval = interval
        stopMonitoring()

        isMonitoring = true
        monitoringTask = Task {
            while !Task.isCancelled {
                await performHealthCheck()
                try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        isMonitoring = false
    }

    func performHealthCheck() async {
        lastCheckAt = Date()

        for server in registry.servers where server.isEnabled {
            let status = await checkServerHealth(server)

            do {
                try await registry.updateHealthStatus(
                    for: server.id,
                    status: status.0,
                    message: status.1
                )
            } catch {
                // Ignore update errors during health check
            }
        }
    }

    func checkServerHealth(_ server: MCPServer) async -> (HealthStatus, String?) {
        switch server.type {
        case .http, .sse:
            return await checkRemoteServerHealth(server)
        case .stdio:
            return await checkStdioServerHealth(server)
        }
    }

    private func checkRemoteServerHealth(_ server: MCPServer) async -> (HealthStatus, String?) {
        guard let urlString = server.configuration.url,
              let url = URL(string: urlString) else {
            return (.unhealthy, "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        // Add headers if present
        if let headers = server.configuration.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return (.unhealthy, "Invalid response")
            }

            switch httpResponse.statusCode {
            case 200..<300:
                return (.healthy, nil)
            case 401, 403:
                return (.needsAuth, "Authentication required")
            case 408, 504:
                return (.degraded, "Server slow to respond")
            case 500..<600:
                return (.unhealthy, "Server error: \(httpResponse.statusCode)")
            default:
                return (.degraded, "Unexpected status: \(httpResponse.statusCode)")
            }
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet:
                return (.degraded, "No internet connection")
            case .timedOut:
                return (.degraded, "Connection timed out")
            case .cannotConnectToHost:
                return (.unhealthy, "Cannot connect to server")
            case .secureConnectionFailed:
                return (.unhealthy, "SSL/TLS error")
            default:
                return (.unhealthy, error.localizedDescription)
            }
        } catch {
            return (.unhealthy, error.localizedDescription)
        }
    }

    private func checkStdioServerHealth(_ server: MCPServer) async -> (HealthStatus, String?) {
        // For stdio servers, check if the command exists
        guard let command = server.configuration.command else {
            return (.unhealthy, "No command specified")
        }

        // Check Claude Desktop logs for this server
        let logErrors = logParser.getRecentErrors(for: server.name)

        if let lastError = logErrors.first {
            if lastError.message.contains("authentication") ||
               lastError.message.contains("auth") ||
               lastError.message.contains("401") {
                return (.needsAuth, lastError.message)
            }

            if lastError.timestamp.timeIntervalSinceNow > -300 { // Within last 5 minutes
                return (.unhealthy, lastError.message)
            }
        }

        // Check if command is accessible
        let commandPath = findCommand(command)
        if commandPath == nil && !command.hasPrefix("/") && !command.contains("npx") {
            return (.degraded, "Command '\(command)' not found in PATH")
        }

        return (.healthy, nil)
    }

    private func findCommand(_ command: String) -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            // Command not found
        }

        return nil
    }

    func setCheckInterval(_ interval: TimeInterval) {
        checkInterval = interval
        if isMonitoring {
            startMonitoring(interval: interval)
        }
    }
}
