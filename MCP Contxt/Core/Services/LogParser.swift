//
//  LogParser.swift
//  MCP Contxt
//
//  Parse Claude Desktop logs for MCP server errors
//

import Foundation

class LogParser {
    static let shared = LogParser()

    private let fileManager = FileManager.default

    private var logsDirectory: URL {
        let home = fileManager.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("Claude")
    }

    private init() {}

    func getLogFiles() -> [URL] {
        guard fileManager.fileExists(atPath: logsDirectory.path) else {
            return []
        }

        do {
            let files = try fileManager.contentsOfDirectory(
                at: logsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            return files
                .filter { $0.lastPathComponent.hasPrefix("mcp-server-") }
                .sorted { file1, file2 in
                    let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return date1 > date2
                }
        } catch {
            return []
        }
    }

    func getLogFile(for serverName: String) -> URL? {
        getLogFiles().first { $0.lastPathComponent.contains(serverName) }
    }

    func readRecentLogs(for serverName: String, lines: Int = 100) -> [String] {
        guard let logFile = getLogFile(for: serverName) else {
            return []
        }

        return readLastLines(of: logFile, count: lines)
    }

    func getRecentErrors(for serverName: String) -> [LogError] {
        let logs = readRecentLogs(for: serverName)
        return parseErrors(from: logs)
    }

    func getAllRecentErrors() -> [String: [LogError]] {
        var errorsByServer: [String: [LogError]] = [:]

        for logFile in getLogFiles() {
            let serverName = extractServerName(from: logFile.lastPathComponent)
            let logs = readLastLines(of: logFile, count: 50)
            let errors = parseErrors(from: logs)

            if !errors.isEmpty {
                errorsByServer[serverName] = errors
            }
        }

        return errorsByServer
    }

    private func readLastLines(of url: URL, count: Int) -> [String] {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = content.components(separatedBy: .newlines)
        return Array(lines.suffix(count))
    }

    private func parseErrors(from lines: [String]) -> [LogError] {
        var errors: [LogError] = []

        for line in lines {
            if let error = parseErrorLine(line) {
                errors.append(error)
            }
        }

        return errors.sorted { $0.timestamp > $1.timestamp }
    }

    private func parseErrorLine(_ line: String) -> LogError? {
        // Common error patterns in MCP logs
        let errorPatterns = [
            "error",
            "Error",
            "ERROR",
            "failed",
            "Failed",
            "FAILED",
            "exception",
            "Exception",
            "EXCEPTION",
            "refused",
            "timeout",
            "Timeout",
            "unauthorized",
            "Unauthorized",
            "403",
            "401",
            "500",
            "502",
            "503",
            "504"
        ]

        guard errorPatterns.contains(where: { line.contains($0) }) else {
            return nil
        }

        // Try to extract timestamp
        let timestamp = extractTimestamp(from: line) ?? Date()

        // Extract the error message
        let message = cleanErrorMessage(line)

        return LogError(timestamp: timestamp, message: message, rawLine: line)
    }

    private func extractTimestamp(from line: String) -> Date? {
        // Common timestamp patterns
        let patterns = [
            "\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}",  // ISO 8601
            "\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}",  // Standard
            "\\d{2}:\\d{2}:\\d{2}"                          // Time only
        ]

        for pattern in patterns {
            if let range = line.range(of: pattern, options: .regularExpression) {
                let dateString = String(line[range])
                if let date = parseDate(dateString) {
                    return date
                }
            }
        }

        return nil
    }

    private func parseDate(_ string: String) -> Date? {
        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "HH:mm:ss"
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }

        return nil
    }

    private func cleanErrorMessage(_ line: String) -> String {
        // Remove timestamp prefix if present
        var message = line

        if let range = line.range(of: "\\[.*?\\]", options: .regularExpression) {
            message = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        // Limit length
        if message.count > 200 {
            message = String(message.prefix(200)) + "..."
        }

        return message
    }

    private func extractServerName(from filename: String) -> String {
        // Format: mcp-server-{name}.log
        var name = filename
            .replacingOccurrences(of: "mcp-server-", with: "")
            .replacingOccurrences(of: ".log", with: "")

        // Handle rotation suffixes like .1, .2
        if let dotIndex = name.lastIndex(of: "."),
           let suffix = Int(name[name.index(after: dotIndex)...]) {
            name = String(name[..<dotIndex])
        }

        return name
    }
}

// MARK: - Log Error Model

struct LogError: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let rawLine: String

    var relativeTime: String {
        timestamp.relativeTimeString
    }
}
