//
//  ConnectionTester.swift
//  MCPContxt
//
//  Tests MCP server connectivity before saving
//

import Foundation

enum ConnectionTestResult {
    case success
    case authRequired
    case unreachable(String)
    case invalidURL

    var isReachable: Bool {
        switch self {
        case .success, .authRequired: return true
        case .unreachable, .invalidURL: return false
        }
    }

    var isAuthRequired: Bool {
        if case .authRequired = self { return true }
        return false
    }
}

class ConnectionTester {

    /// Test connectivity to an HTTP/SSE MCP server
    static func test(url: String, headers: [String: String]?) async -> ConnectionTestResult {
        guard let serverURL = URL(string: url) else {
            return .invalidURL
        }

        var request = URLRequest(url: serverURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .unreachable("Invalid response")
            }

            switch httpResponse.statusCode {
            case 200...299:
                return .success
            case 401, 403:
                return .authRequired
            case 404:
                return .unreachable("Not found (404)")
            case 500...599:
                return .unreachable("Server error (\(httpResponse.statusCode))")
            default:
                // Many MCP servers return non-200 for GET but are still reachable
                return .success
            }
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet:
                return .unreachable("No internet connection")
            case .timedOut:
                return .unreachable("Connection timed out")
            case .cannotFindHost:
                return .unreachable("Host not found")
            case .cannotConnectToHost:
                return .unreachable("Cannot connect to host")
            case .secureConnectionFailed:
                return .unreachable("SSL/TLS error")
            default:
                return .unreachable(error.localizedDescription)
            }
        } catch {
            return .unreachable(error.localizedDescription)
        }
    }

    /// Test if a stdio command exists in PATH
    static func testCommand(_ command: String) async -> ConnectionTestResult {
        guard !command.isEmpty else {
            return .invalidURL
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        // Include common paths
        var env = ProcessInfo.processInfo.environment
        let additionalPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(NSHomeDirectory())/.local/bin",
            "\(NSHomeDirectory())/.nvm/versions/node/*/bin"
        ]
        if let existingPath = env["PATH"] {
            env["PATH"] = additionalPaths.joined(separator: ":") + ":" + existingPath
        }
        process.environment = env

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return .success
            } else {
                return .unreachable("Command '\(command)' not found in PATH")
            }
        } catch {
            return .unreachable(error.localizedDescription)
        }
    }
}
